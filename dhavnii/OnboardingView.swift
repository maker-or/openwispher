//
//  OnboardingView.swift
//  OpenWispher
//
//  First-launch onboarding flow for permissions.
//

import SwiftUI

/// Onboarding view for permission requests
struct OnboardingView: View {
    var permissionManager: PermissionManager
    let onComplete: () -> Void

    @State private var currentStep = 0
    @State private var showAccessibilityHint = false
    @State private var showAccessibilityAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: UIConstants.Icon.extraLarge))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Welcome to OpenWispher")
                    .font(.largeTitle)
                    .bold()

                Text("Speech-to-Text, instantly")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            .padding(.bottom, 30)
            .glassEffect(.regular)

            Divider()

            // Permission steps
            GlassEffectContainer(spacing: 24) {
                PermissionStepView(
                    icon: "mic.fill",
                    title: "Microphone Access",
                    description: "Required to capture your voice for transcription.",
                    isGranted: permissionManager.hasMicrophonePermission,
                    showHint: false,
                    action: {
                        Task {
                            await permissionManager.requestMicrophonePermission()
                        }
                    }
                )

                PermissionStepView(
                    icon: "hand.raised.fill",
                    title: "Accessibility Access",
                    description: "Required to auto-paste transcribed text into focused fields.",
                    isGranted: permissionManager.hasAccessibilityPermission,
                    showHint: showAccessibilityHint,
                    action: {
                        showAccessibilityAlert = true
                    }
                )
            }
            .padding(30)

            Spacer()

            // Continue button
            Button(action: onComplete) {
                Text(permissionManager.hasAllPermissions ? "Get Started" : "Continue Anyway")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.glassProminent)
            .padding(.horizontal, 30)
            .padding(.bottom, 30)

            // Shortcut hint
            Text("Press ⌥ + Space to start recording")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
        }
        .frame(width: UIConstants.Window.onboardingWidth, height: UIConstants.Window.onboardingHeight)
        .task {
            // Initial check
            permissionManager.checkPermissions()
            
            // Continuous monitoring while on onboarding screen
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(UIConstants.Monitoring.aggressiveInterval))
                if !Task.isCancelled {
                    permissionManager.checkPermissions()
                }
            }
        }
        .alert("Enable Accessibility Access", isPresented: $showAccessibilityAlert) {
            Button("Open System Settings") {
                showAccessibilityHint = true
                permissionManager.requestAccessibilityPermission()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "To enable auto-paste:\n\n1. Click 'Open System Settings'\n2. Find 'OpenWispher' in the list\n3. Toggle it ON\n4. Return to this app\n\nThe checkmark will appear automatically when enabled."
            )
        }
    }
}

/// Individual permission step row
struct PermissionStepView: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let showHint: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Content row
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isGranted ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: isGranted ? "checkmark" : icon)
                        .font(.title2)
                        .foregroundColor(isGranted ? .green : .orange)
                }

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Status indicator
                if isGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
            }
            
            // Action button - separate row
            if !isGranted {
                Button(action: action) {
                    HStack(spacing: 6) {
                        Text("Grant Permission")
                            .font(.subheadline)
                            .font(.subheadline.weight(.medium))
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .glassEffect(.regular)
        .overlay(alignment: .bottom) {
            if showHint && !isGranted {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Enable 'OpenWispher' in System Settings")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                )
                .offset(y: 75)
            }
        }
    }
}

#Preview {
    OnboardingView(permissionManager: PermissionManager()) {}
}
