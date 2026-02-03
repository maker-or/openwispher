//
//  OnboardingView.swift
//  OpenWispher
//
//  First-launch onboarding flow for permissions.
//

import AppKit
import SwiftUI

/// Onboarding view for permission requests
struct OnboardingView: View {
    var permissionManager: PermissionManager
    let onComplete: () -> Void

    @State private var currentStep: OnboardingStep = .welcome

    private enum OnboardingStep: Int, CaseIterable, Hashable {
        case welcome
        case microphone
        case accessibility
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            stepContent
                .padding(.horizontal, 30)
                .padding(.top, 26)
                .transition(.opacity.combined(with: .move(edge: .trailing)))

            Spacer()

            footerControls
                .padding(.horizontal, 30)
                .padding(.bottom, 24)

            Text("Press ⌥ + Space to start recording")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 18)
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
        .animation(.easeInOut, value: currentStep)
    }

    private var header: some View {
        VStack(spacing: 10) {
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
                .foregroundStyle(.secondary)
        }
        .padding(.top, 40)
        .padding(.bottom, 28)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .welcome:
            OnboardingCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Start dictating in seconds")
                        .font(.title3)
                        .font(.title3.weight(.semibold))
                    Text("OpenWispher lives in your menu bar and types wherever you are. Let’s set up your permissions first.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Image(systemName: "keyboard.badge.ellipsis")
                            .foregroundStyle(.tint)
                        Text("Use ⌥ + Space to start and stop recording.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case .microphone:
            OnboardingCard {
                VStack(alignment: .leading, spacing: 16) {
                    PermissionHeader(
                        title: "Microphone",
                        description: "Used to capture your voice for transcription.",
                        isGranted: permissionManager.hasMicrophonePermission,
                        icon: "mic.fill",
                        color: .blue
                    )

                    if !permissionManager.hasMicrophonePermission {
                        Button("Request Access") {
                            Task {
                                await permissionManager.requestMicrophonePermission()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .help("Grant microphone access")
                        .accessibilityLabel("Request microphone access")
                    }
                }
            }
        case .accessibility:
            OnboardingCard {
                VStack(alignment: .leading, spacing: 16) {
                    PermissionHeader(
                        title: "Accessibility",
                        description: "Allows auto‑paste and global hotkey support.",
                        isGranted: permissionManager.hasAccessibilityPermission,
                        icon: "hand.raised.fill",
                        color: .purple
                    )

                    if !permissionManager.hasAccessibilityPermission {
                        Button("Open System Settings") {
                            permissionManager.requestAccessibilityPermission()
                        }
                        .buttonStyle(.borderedProminent)
                        .help("Open System Settings to enable accessibility")
                        .accessibilityLabel("Open System Settings for accessibility")

                        VStack(alignment: .leading, spacing: 6) {
                            Text("How to enable:")
                                .font(.caption)
                                .font(.caption.weight(.semibold))
                            Text("System Settings → Privacy & Security → Accessibility → OpenWispher")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 6)
                    }
                }
            }
        }
    }

    private var footerControls: some View {
        HStack {
            Button("Back") {
                goToPreviousStep()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.leftArrow, modifiers: [.command])
            .disabled(isFirstStep)
            .help("Go back")
            .accessibilityLabel("Back")

            Spacer()

            if isLastStep {
                Button(permissionManager.hasAllPermissions ? "Finish" : "Finish Anyway") {
                    finishOnboarding()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [.command])
                .help("Finish onboarding")
                .accessibilityLabel("Finish onboarding")
            } else {
                Button("Next") {
                    goToNextStep()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.rightArrow, modifiers: [.command])
                .help("Next step")
                .accessibilityLabel("Next step")
            }
        }
    }

    private var isFirstStep: Bool {
        currentStep == .welcome
    }

    private var isLastStep: Bool {
        currentStep == .accessibility
    }

    private func goToNextStep() {
        guard let next = nextStep else { return }
        playChime()
        withAnimation(.easeInOut) {
            currentStep = next
        }
    }

    private func goToPreviousStep() {
        guard let previous = previousStep else { return }
        playChime()
        withAnimation(.easeInOut) {
            currentStep = previous
        }
    }

    private var nextStep: OnboardingStep? {
        switch currentStep {
        case .welcome: return .microphone
        case .microphone: return .accessibility
        case .accessibility: return nil
        }
    }

    private var previousStep: OnboardingStep? {
        switch currentStep {
        case .welcome: return nil
        case .microphone: return .welcome
        case .accessibility: return .microphone
        }
    }

    private func finishOnboarding() {
        playChime()
        onComplete()
    }

    private func playChime() {
        NSSound(named: "Glass")?.play()
    }
}

private struct OnboardingCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
    }
}

private struct PermissionHeader: View {
    let title: String
    let description: String
    let isGranted: Bool
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: isGranted ? "checkmark" : icon)
                    .font(.title3)
                    .foregroundStyle(isGranted ? .green : color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                Text(isGranted ? "Granted" : "Not Granted")
            }
            .font(.caption)
            .foregroundStyle(isGranted ? .green : .orange)
        }
    }
}

#Preview {
    OnboardingView(permissionManager: PermissionManager()) {}
}
