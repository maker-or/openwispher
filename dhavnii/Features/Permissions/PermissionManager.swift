//
//  PermissionManager.swift
//  OpenWispher
//
//  Enhanced permission checking and requesting for Microphone and Accessibility.
//  Includes better monitoring, retry logic, and reliability improvements.
//

import AVFoundation
import AppKit
import ApplicationServices
import Foundation
import SwiftUI

/// Manages permission requests for Microphone and Accessibility with enhanced monitoring
@MainActor
@Observable
internal class PermissionManager {
    internal var hasMicrophonePermission = false
    internal var hasAccessibilityPermission = false
    internal var isMonitoring = false

    private var permissionCheckTimer: Timer?
    private var appActivationObserver: NSObjectProtocol?
    private var lastAccessibilityCheck: Date = .distantPast
    private let accessibilityCheckInterval: TimeInterval = 1.0
    private var lastAccessibilityState: Bool = false
    private var accessibilityStateChangeCount: Int = 0
    private let accessibilityStateChangeThreshold: Int = 3 // Require 3 consistent checks before changing state
    private var isRestarting: Bool = false
    private var lastRestartTime: Date = .distantPast
    private let restartCooldownInterval: TimeInterval = 10.0 // Prevent restarts within 10 seconds
    private let restartFlagKey = "openwispher_just_restarted_for_permission"

    init() {
        // Initialize last known state to current state to prevent false positives
        lastAccessibilityState = AXIsProcessTrusted()
        
        // Check if we just restarted - if so, clear the flag and skip restart logic for a while
        if UserDefaults.standard.bool(forKey: restartFlagKey) {
            print("🔄 App just restarted - clearing restart flag and setting cooldown")
            UserDefaults.standard.removeObject(forKey: restartFlagKey)
            UserDefaults.standard.synchronize()
            // Set cooldown to prevent immediate re-restart
            lastRestartTime = Date()
        }
        
        setupObservers()
        checkPermissions()
        startBackgroundMonitoring()
    }

    deinit {
        // Note: Since deinit is nonisolated and the class is @MainActor,
        // cleanup is handled by the system when the instance is deallocated.
        // Timer invalidation and observer removal happen automatically.
    }

    // MARK: - Setup

    internal func setupObservers() {
        // Monitor app activation
        appActivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                Task { @MainActor [weak self] in
                    self?.checkPermissions()
                }
            }
        }

        // Monitor workspace activation (when returning from System Settings)
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication,
                app.bundleIdentifier == Bundle.main.bundleIdentifier
            {
                // Our app was activated - check permissions
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    Task { @MainActor in
                        self.checkPermissions()
                    }
                }
            }
        }
    }

    // MARK: - Background Monitoring

    /// Start background monitoring with slower polling (only when needed)
    private func startBackgroundMonitoring() {
        // Only monitor if we don't have all permissions
        guard !hasAllPermissions else { return }

        permissionCheckTimer?.invalidate()
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkPermissions()
            }
        }
    }

    /// Start aggressive monitoring (during permission flow)
    func startAggressiveMonitoring() {
        print("🔍 Starting aggressive permission monitoring...")
        isMonitoring = true

        permissionCheckTimer?.invalidate()
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkPermissions()

                // Stop aggressive monitoring after permissions are granted
                if self?.hasAllPermissions == true {
                    self?.stopAggressiveMonitoring()
                }
            }
        }

        // Auto-stop after 90 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 90) { [weak self] in
            Task { @MainActor [weak self] in
                self?.stopAggressiveMonitoring()
            }
        }
    }

    private func stopAggressiveMonitoring() {
        print("🔍 Stopping aggressive monitoring")
        isMonitoring = false
        permissionCheckTimer?.invalidate()
        startBackgroundMonitoring()
    }

    internal func stopMonitoring() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
        isMonitoring = false
    }

    // MARK: - Permission Checking

    /// Check current permission status for all permissions
    internal func checkPermissions() {
        checkMicrophonePermission()
        checkAccessibilityPermission()
    }

    /// Check microphone permission status
    internal func checkMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        let granted = status == .authorized

        // Only update if value changed to avoid unnecessary view updates
        if hasMicrophonePermission != granted {
            print("🎤 Microphone permission changed: \(granted)")
            hasMicrophonePermission = granted
        }
    }

    /// Check accessibility permission status with rate limiting and debouncing
    internal func checkAccessibilityPermission() {
        // Rate limit accessibility checks (system call can be expensive)
        let now = Date()
        guard now.timeIntervalSince(lastAccessibilityCheck) >= (isMonitoring ? 0.3 : 1.0) else {
            return
        }
        lastAccessibilityCheck = now

        // Check accessibility permission using standard API
        let trusted = verifyAccessibilityPermission()

        // Debounce: Require consistent state changes before updating
        // This prevents flickering when the API returns inconsistent results
        if trusted == lastAccessibilityState {
            // State is consistent with previous check - reset counter
            accessibilityStateChangeCount = 0
            
            // Update state if it differs from current (already on main actor)
            if hasAccessibilityPermission != trusted {
                print("🔓 Accessibility permission changed: \(trusted)")
                hasAccessibilityPermission = trusted

                // If permission was just granted, restart the app (only if not in cooldown)
                if trusted && !shouldSkipRestart() {
                    print("✅ Accessibility permission granted - restarting app...")
                    stopAggressiveMonitoring()
                    
                    // Delay restart slightly to allow UI to update
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        restartApplication()
                    }
                } else if !trusted && isMonitoring {
                    // Permission was revoked - stop aggressive monitoring
                    stopAggressiveMonitoring()
                }
            }
        } else {
            // State changed from last check - increment counter
            accessibilityStateChangeCount += 1
            
            // Only update if we've seen consistent state changes (prevents flickering)
            if accessibilityStateChangeCount >= accessibilityStateChangeThreshold {
                // Update the last known state
                lastAccessibilityState = trusted
                accessibilityStateChangeCount = 0
                
                // Update state (already on main actor)
                if hasAccessibilityPermission != trusted {
                    print("🔓 Accessibility permission changed (after debounce): \(trusted)")
                    hasAccessibilityPermission = trusted

                    // If permission was just granted, restart the app (only if not in cooldown)
                    if trusted && !shouldSkipRestart() {
                        print("✅ Accessibility permission granted - restarting app...")
                        stopAggressiveMonitoring()
                        
                        // Delay restart slightly to allow UI to update
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: UInt64(UIConstants.Delay.restartDelay * 1_000_000_000))
                            restartApplication()
                        }
                    } else if !trusted && isMonitoring {
                        // Permission was revoked - stop aggressive monitoring
                        stopAggressiveMonitoring()
                    }
                }
            }
        }
    }
    
    /// Verify accessibility permission - use only the standard reliable API
    private func verifyAccessibilityPermission() -> Bool {
        // Use only the standard API - it's reliable and doesn't have false negatives
        // The secondary check was causing flickering because it can fail for reasons
        // unrelated to permission (e.g., no focused element, app doesn't support accessibility)
        return AXIsProcessTrusted()
    }
    
    /// Check if we should skip restart (cooldown period or already restarting)
    private func shouldSkipRestart() -> Bool {
        // Don't restart if we're already restarting
        if isRestarting {
            print("⚠️ Already restarting - skipping")
            return true
        }
        
        // Don't restart if we're in cooldown period
        let timeSinceLastRestart = Date().timeIntervalSince(lastRestartTime)
        if timeSinceLastRestart < restartCooldownInterval {
            print("⚠️ In restart cooldown period (\(Int(restartCooldownInterval - timeSinceLastRestart))s remaining) - skipping")
            return true
        }
        
        return false
    }
    
    /// Restart the application to ensure accessibility permission is properly recognized
    private func restartApplication() {
        // Prevent restart loops
        guard !shouldSkipRestart() else {
            print("⚠️ Skipping restart - cooldown or already restarting")
            return
        }
        
        print("🔄 Restarting application to apply accessibility permission...")
        
        // Mark that we're restarting
        isRestarting = true
        lastRestartTime = Date()
        
        // Set flag in UserDefaults so the new instance knows it just restarted
        UserDefaults.standard.set(true, forKey: restartFlagKey)
        UserDefaults.standard.synchronize()
        
        // Get the app's bundle path
        let bundlePath = Bundle.main.bundlePath
        guard !bundlePath.isEmpty else {
            print("❌ Failed to get bundle path")
            isRestarting = false
            UserDefaults.standard.removeObject(forKey: restartFlagKey)
            self.showRestartAlert()
            return
        }
        
        // Use the 'open' command to launch a new instance
        // The -n flag opens a new instance even if the app is already running
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.launchPath = "/usr/bin/open"
            task.arguments = ["-n", bundlePath]
            
            do {
                try task.run()
                task.waitUntilExit()
                
                if task.terminationStatus == 0 {
                    print("✅ New app instance launched successfully")
                    
                    // Give it a moment to fully launch, then terminate this instance
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        print("🛑 Terminating old instance")
                        NSApplication.shared.terminate(nil)
                    }
                } else {
                    print("❌ Failed to launch app (exit code: \(task.terminationStatus))")
                    DispatchQueue.main.async {
                        self.isRestarting = false
                        UserDefaults.standard.removeObject(forKey: self.restartFlagKey)
                        self.showRestartAlert()
                    }
                }
            } catch {
                print("❌ Failed to restart app: \(error)")
                DispatchQueue.main.async {
                    self.isRestarting = false
                    UserDefaults.standard.removeObject(forKey: self.restartFlagKey)
                    self.showRestartAlert()
                }
            }
        }
    }
    
    /// Show alert to user if automatic restart fails
    private func showRestartAlert() {
        let alert = NSAlert()
        alert.messageText = "Restart Required"
        alert.informativeText = "Accessibility permission has been granted. Please restart the app manually for it to take effect."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Permission Requesting

    /// Request microphone permission with async/await
    @MainActor
    internal func requestMicrophonePermission() async -> Bool {
        print("🎤 Requesting microphone permission...")

        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            print("✅ Microphone already authorized")
            hasMicrophonePermission = true
            return true

        case .notDetermined:
            // Request permission
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }

            print(granted ? "✅ Microphone permission granted" : "❌ Microphone permission denied")
            hasMicrophonePermission = granted
            return granted

        case .denied, .restricted:
            print("⚠️ Microphone permission denied/restricted - opening System Settings")
            openMicrophoneSettings()
            startAggressiveMonitoring()
            return false

        @unknown default:
            print("⚠️ Unknown microphone permission status")
            hasMicrophonePermission = false
            return false
        }
    }

    /// Request accessibility permission with multiple strategies
    internal func requestAccessibilityPermission() {
        print("🔓 Requesting Accessibility permission...")

        // Check current status first
        if AXIsProcessTrusted() {
            print("✅ Accessibility already granted")
            hasAccessibilityPermission = true
            return
        }

        // Strategy 1: Try to show system prompt (works on some macOS versions)
        let options =
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let promptResult = AXIsProcessTrustedWithOptions(options)

        if promptResult {
            print("✅ Accessibility permission granted via prompt")
            hasAccessibilityPermission = true
            return
        }

        print("📋 System prompt shown, opening System Settings as backup...")

        // Strategy 2: Open System Settings (always works)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            Task { @MainActor in
                self.openAccessibilitySettings()
            }
        }

        // Start aggressive monitoring to detect when permission is granted
        startAggressiveMonitoring()
    }

    /// Force re-request accessibility permission (for settings UI)
    internal func retryAccessibilityPermission() {
        print("🔄 Retrying Accessibility permission...")
        openAccessibilitySettings()
        startAggressiveMonitoring()
    }

    // MARK: - System Settings Navigation

    private func openMicrophoneSettings() {
        if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        {
            NSWorkspace.shared.open(url)
        }
    }

    private func openAccessibilitySettings() {
        // Try modern System Settings URL first (macOS 13+)
        if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        {
            NSWorkspace.shared.open(url)
        }
    }

    /// Open general privacy settings
    internal func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")
        {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Status

    /// Check if all permissions are granted
    internal var hasAllPermissions: Bool {
        hasMicrophonePermission && hasAccessibilityPermission
    }

    /// Get detailed permission status message
    internal var permissionStatusMessage: String {
        switch (hasMicrophonePermission, hasAccessibilityPermission) {
        case (true, true):
            return "All permissions granted"
        case (true, false):
            return "Accessibility permission required"
        case (false, true):
            return "Microphone permission required"
        case (false, false):
            return "Microphone and Accessibility permissions required"
        }
    }

    /// Get missing permissions list
    internal var missingPermissions: [String] {
        var missing: [String] = []
        if !hasMicrophonePermission {
            missing.append("Microphone")
        }
        if !hasAccessibilityPermission {
            missing.append("Accessibility")
        }
        return missing
    }
}
