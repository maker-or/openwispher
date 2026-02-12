//
//  openwispherApp.swift
//  openwispher
//
//  Main application entry point with Settings window and menu bar.
//

import AppKit
import SwiftData
import SwiftUI

@main
internal struct openwispherApp: App {
    @State private var appState = AppState()
    @State private var permissionManager = PermissionManager()
    @State private var historyManager: HistoryManager?

    @State private var transcriptionService: TranscriptionService?
    @State private var hotkeyManager: HotkeyManager?
    @State private var notchController: NotchWindowController?

    // SwiftData container
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([TranscriptionRecord.self, HistoryPreferences.self])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    internal var body: some Scene {
        // Main Window Group
        WindowGroup {
            AppContentView(
                appState: appState,
                permissionManager: permissionManager,
                historyManagerRef: $historyManager,
                transcriptionService: $transcriptionService,
                hotkeyManager: $hotkeyManager,
                notchController: $notchController
            )
            .onReceive(
                NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            ) { _ in
                permissionManager.checkPermissions()
                AnalyticsManager.shared.trackAppOpened()
            }
            .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About OpenWispher") {
                    NSApp.orderFrontStandardAboutPanel(
                        options: [
                            NSApplication.AboutPanelOptionKey.applicationName: "OpenWispher",
                            NSApplication.AboutPanelOptionKey.applicationVersion: "1.0.0",
                            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"):
                                "© 2025 OpenWispher",
                        ]
                    )
                }
            }

            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    NotificationCenter.default.post(
                        name: Notification.Name("OpenSettingsWindow"), object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        // Settings Window - Using Window scene for full control (same as HomeView)
        Window("Settings", id: "settings") {
            SettingsViewWrapper(
                permissionManager: permissionManager,
                appState: appState,
                hotkeyManager: $hotkeyManager
            )
            .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

}

/// Content view that manages environment and setup
private struct AppContentView: View {
    @Bindable var appState: AppState
    var permissionManager: PermissionManager
    @Binding var historyManagerRef: HistoryManager?
    @Binding var transcriptionService: TranscriptionService?
    @Binding var hotkeyManager: HotkeyManager?
    @State private var escapeKeyMonitor: EscapeKeyMonitor?
    @Binding var notchController: NotchWindowController?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @State private var hasSetup = false
    @State private var localHistoryManager: HistoryManager?
    @State private var updateManager = UpdateManager()
    @State private var hasCheckedUpdatesOnLaunch = false

    var body: some View {
        Group {
            if !appState.hasCompletedOnboarding {
                OnboardingView(permissionManager: permissionManager, hotkeyManager: hotkeyManager) {
                    appState.hasCompletedOnboarding = true
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    appState.hasMicrophonePermission = permissionManager.hasMicrophonePermission
                    appState.hasAccessibilityPermission =
                        permissionManager.hasAccessibilityPermission
                }
            } else {
                HomeView(
                    appState: appState,
                    permissionManager: permissionManager,
                    historyManager: localHistoryManager
                )
            }
        }
        .background(WindowConfigurator())
        .seamlessToolbarWindowBackground()
        .onAppear {
            if !hasSetup {
                performSetup()
                hasSetup = true
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: Notification.Name("OpenSettingsWindow"))
        ) { _ in
            openWindow(id: "settings")
        }
        .task {
            guard !hasCheckedUpdatesOnLaunch else { return }
            hasCheckedUpdatesOnLaunch = true
            await updateManager.checkForUpdates()

            guard updateManager.updateAvailable else { return }
            let latestVersion = updateManager.latestVersion ?? "latest"
            FeedbackManager.shared.show(
                FeedbackMessage(
                    type: .info,
                    title: "Update available",
                    message: "Version \(latestVersion) is ready to download.",
                    duration: UIConstants.Toast.infoDuration,
                    action: FeedbackAction(title: "Download") {
                        updateManager.openDownloadURL()
                    }
                )
            )
        }
        .onChange(of: appState.recordingState) { _, newValue in
            switch newValue {
            case .recording:
                escapeKeyMonitor?.start()
            default:
                escapeKeyMonitor?.stop()
            }
        }
        .withToasts()
    }

    private func performSetup() {
        // Initialize history manager with shared context
        let manager = HistoryManager(modelContext: modelContext)
        localHistoryManager = manager
        historyManagerRef = manager

        // Load selected transcription provider from UserDefaults
        let savedProviderRaw = UserDefaults.standard.string(forKey: "selectedTranscriptionProvider")
        let selectedProvider =
            savedProviderRaw.flatMap { TranscriptionProviderType(rawValue: $0) } ?? .groq

        // Initialize transcription service with selected provider
        let service = TranscriptionService(appState: appState, selectedProvider: selectedProvider)
        service.historyManager = manager
        transcriptionService = service

        // Initialize notch overlay
        let controller = NotchWindowController(appState: appState)
        controller.show()
        notchController = controller

        // Initialize hotkey manager
        let savedHotkey = HotkeyDefinition.loadFromDefaults()
        let hotkey = HotkeyManager(
            hotkey: savedHotkey,
            activationMode: HotkeyActivationMode.loadFromDefaults(),
            onToggle: { [weak service, weak appState] in
                guard let service = service, let appState = appState else {
                    print("❌ Hotkey triggered but service/appState is nil")
                    return
                }

                print("🎯 Hotkey triggered. Current state: \(appState.recordingState)")
                // Use savedHotkey to avoid capturing 'hotkey' before declaration
                AnalyticsManager.shared.trackHotkeyPressed(hotkey: savedHotkey)

                switch appState.recordingState {
                case .recording:
                    print("⏹️ Stopping recording...")
                    service.stopRecording()
                case .idle:
                    print("▶️ Starting recording...")
                    service.startRecording()
                default:
                    print("⚠️ Cannot toggle - state is \(appState.recordingState)")
                }
            },
            onHoldStart: { [weak service, weak appState] in
                guard let service = service, let appState = appState else { return }
                guard appState.recordingState == .idle else {
                    print("⚠️ Cannot start hold recording - state is \(appState.recordingState)")
                    return
                }
                print("▶️ Hold started. Starting recording...")
                AnalyticsManager.shared.trackHotkeyPressed(hotkey: savedHotkey)
                service.startRecording()
            },
            onHoldEnd: { [weak service, weak appState] in
                guard let service = service, let appState = appState else { return }
                guard appState.recordingState == .recording else {
                    print("⚠️ Hold ended but recording is not active")
                    return
                }
                print("⏹️ Hold released. Stopping recording...")
                service.stopRecording()
            })
        hotkey.startMonitoring()
        hotkeyManager = hotkey

        escapeKeyMonitor = EscapeKeyMonitor { [weak service, weak appState] in
            Task { @MainActor in
                guard let service, let appState else { return }
                guard appState.recordingState == .recording else { return }
                print("⏹️ Escape pressed. Cancelling recording...")
                service.cancelRecording()
            }
        }
        // Update permission state
        appState.hasMicrophonePermission = permissionManager.hasMicrophonePermission
        appState.hasAccessibilityPermission = permissionManager.hasAccessibilityPermission

        // Check if onboarding was completed before (properly persist this)
        let defaults = UserDefaults.standard
        resetOnboardingIfNewBuild(defaults: defaults)
        let shouldForceOnboarding = defaults.bool(forKey: "forceOnboardingOnLaunch")
        print("🧭 Onboarding: forceOnboardingOnLaunch=\(shouldForceOnboarding)")
        if shouldForceOnboarding {
            defaults.set(false, forKey: "hasCompletedOnboarding")
            defaults.removeObject(forKey: "forceOnboardingOnLaunch")
            print("🧭 Onboarding: forced reset of hasCompletedOnboarding")
        }

        let hasCompleted = defaults.bool(forKey: "hasCompletedOnboarding")
        print("🧭 Onboarding: hasCompletedOnboarding=\(hasCompleted)")
        appState.hasCompletedOnboarding = hasCompleted

        if hasCompleted {
            // Warm up keychain access only after onboarding
            _ = SecureStorage.retrieveAPIKey(for: selectedProvider)
        }

        // If onboarding is complete, still check permissions on launch
        if hasCompleted {
            permissionManager.checkPermissions()
        }
    }

    private func resetOnboardingIfNewBuild(defaults: UserDefaults) {
        let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        let lastBuild = defaults.string(forKey: "lastOnboardingBuild")
        let executableTimestamp =
            Bundle.main.executableURL
            .flatMap {
                try? FileManager.default.attributesOfItem(atPath: $0.path)[.modificationDate]
                    as? Date
            }
            .map { String($0.timeIntervalSince1970) } ?? "unknown"
        let buildSignature = "\(currentBuild)|\(executableTimestamp)"
        let lastSignature = defaults.string(forKey: "lastOnboardingBuildSignature")

        guard lastSignature != buildSignature else {
            return
        }

        defaults.set(currentBuild, forKey: "lastOnboardingBuild")
        defaults.set(buildSignature, forKey: "lastOnboardingBuildSignature")
        defaults.set(false, forKey: "hasCompletedOnboarding")
        print("🧭 Onboarding: new build detected (\(lastBuild ?? "none") -> \(currentBuild))")
    }

}

// Note: MainView, StatusIndicator, TranscriptionPreview, PermissionWarningView,
// PermissionInfoCard, TranscriptionHistoryList, and TranscriptionRowItem have been removed
// as they were legacy/dead code. The main UI now uses HomeView exclusively.

/// Wrapper for settings view to inject environment
private struct SettingsViewWrapper: View {
    var permissionManager: PermissionManager
    var appState: AppState
    @Binding var hotkeyManager: HotkeyManager?

    @Environment(\.modelContext) private var modelContext
    @State private var historyManager: HistoryManager?

    var body: some View {
        SettingsView(
            permissionManager: permissionManager,
            appState: appState,
            hotkeyManager: $hotkeyManager,
            historyManager: historyManager
        )
        .background(WindowConfigurator())
        .seamlessToolbarWindowBackground()
        .onAppear {
            if historyManager == nil {
                historyManager = HistoryManager(modelContext: modelContext)
            }
        }
    }
}
