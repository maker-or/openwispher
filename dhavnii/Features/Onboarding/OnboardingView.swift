//
//  OnboardingView.swift
//  OpenWispher
//
//  First-launch onboarding flow with native macOS styling and liquid glass.
//

import AppKit
import SwiftUI

/// Onboarding view for permission requests
struct OnboardingView: View {
    var permissionManager: PermissionManager
    let onComplete: () -> Void

    @State private var currentStep: OnboardingStep = .welcome
    @State private var didAutoAdvance = false
    @State private var didAutoComplete = false
    @State private var apiKeyText = ""
    @AppStorage("selectedTranscriptionProvider") private var selectedProviderRaw =
        TranscriptionProviderType.groq.rawValue

    private enum OnboardingStep: Int, CaseIterable, Hashable {
        case welcome
        case provider
        case apiKey
        case permissions
    }

    var body: some View {
        ZStack {

            stepContent
                .padding(.horizontal, 32)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
        .frame(
            width: UIConstants.Window.onboardingWidth, height: UIConstants.Window.onboardingHeight
        )

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
        .task(id: currentStep) {
            guard currentStep == .welcome, !didAutoAdvance else { return }
            didAutoAdvance = true
            try? await Task.sleep(for: .seconds(2.0))
            if !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.6)) {
                    currentStep = .provider
                }
            }
        }
        .onChange(of: permissionManager.hasAllPermissions) { hasAllPermissions in
            guard currentStep == .permissions, hasAllPermissions, !didAutoComplete else { return }
            didAutoComplete = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                finishOnboarding()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }

    // MARK: - Background

    private var onboardingBackground: some View {
        RadialGradient(
            colors: [
                Color(red: 0.18, green: 0.18, blue: 0.19),
                Color(red: 0.12, green: 0.12, blue: 0.13),
            ],
            center: .center,
            startRadius: 0,
            endRadius: 520
        )
        .ignoresSafeArea()
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .welcome:
            WelcomeScreen()
        case .provider:
            ProviderSelectionScreen(selectedProviderRaw: $selectedProviderRaw) {
                playChime()
                withAnimation(.easeInOut(duration: 0.4)) {
                    currentStep = .apiKey
                }
            }
        case .apiKey:
            ApiKeyScreen(
                provider: selectedProvider,
                apiKeyText: $apiKeyText,
                onBack: {
                    playChime()
                    withAnimation(.easeInOut(duration: 0.35)) {
                        currentStep = .provider
                    }
                },
                onContinue: {
                    storeAPIKeyIfNeeded()
                    playChime()
                    withAnimation(.easeInOut(duration: 0.4)) {
                        currentStep = .permissions
                    }
                }
            )
        case .permissions:
            PermissionsStepContent(
                permissionManager: permissionManager, onComplete: finishOnboarding)
        }
    }

    private var selectedProvider: TranscriptionProviderType {
        TranscriptionProviderType(rawValue: selectedProviderRaw) ?? .groq
    }

    private func finishOnboarding() {
        playChime()
        onComplete()
    }

    private func playChime() {
        NSSound(named: "Glass")?.play()
    }

    private func storeAPIKeyIfNeeded() {
        let trimmedKey = apiKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }
        try? SecureStorage.storeAPIKey(trimmedKey, for: selectedProvider)
        apiKeyText = ""
    }
}

// MARK: - Step Content Views

private struct WelcomeScreen: View {
    @State private var isVisible = false

    var body: some View {
        VStack(spacing: 8) {
            Text("Welcome")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(.primary)

            Text("OpenWispher")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.97)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                isVisible = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Welcome. OpenWispher.")
    }
}

private struct PermissionsStepContent: View {
    var permissionManager: PermissionManager
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            PermissionsCard {
                VStack(spacing: 0) {
                    PermissionRow(
                        title: "Microphone",
                        isGranted: permissionManager.hasMicrophonePermission,
                        actionTitle: "Enable"
                    ) {
                        Task {
                            await permissionManager.requestMicrophonePermission()
                        }
                    }

                    Divider()
                        .opacity(0.25)

                    PermissionRow(
                        title: "Accessibility",
                        isGranted: permissionManager.hasAccessibilityPermission,
                        actionTitle: "Open"
                    ) {
                        permissionManager.requestAccessibilityPermission()
                    }
                }
                .padding(.vertical, 10)
            }

            if permissionManager.hasAllPermissions {
                Button("Get Started") {
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Get started")
            } else {
                Button("Continue Anyway") {
                    onComplete()
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Continue anyway")
            }
        }
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct ProviderSelectionScreen: View {
    @Binding var selectedProviderRaw: String
    let onSelect: () -> Void

    private let providers = TranscriptionProviderType.allCases

    var body: some View {
        VStack(spacing: 20) {
            Text("Select the provider")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.primary)

            OnboardingPanel {
                VStack(spacing: 0) {
                    ForEach(providers) { provider in
                        Button {
                            selectedProviderRaw = provider.rawValue
                            onSelect()
                        } label: {
                            HStack {
                                Text(provider.rawValue)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.primary)

                                Spacer()

                                if selectedProviderRaw == provider.rawValue {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)

                        if provider != providers.last {
                            Divider()
                                .opacity(0.2)
                        }
                    }
                }
            }
            .frame(width: 380)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ApiKeyScreen: View {
    let provider: TranscriptionProviderType
    @Binding var apiKeyText: String
    let onBack: () -> Void
    let onContinue: () -> Void

    private var providerLink: URL {
        switch provider {
        case .groq:
            return URL(string: "https://console.groq.com/keys")!
        case .elevenLabs:
            return URL(string: "https://elevenlabs.io/app/developers/api-keys")!
        case .deepgram:
            return URL(string: "https://developers.deepgram.com/docs/create-additional-api-keys")!
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Enter api key")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.primary)

            VStack(spacing: 10) {
                OnboardingPanel {
                    SecureField("", text: $apiKeyText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, design: .monospaced))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .frame(width: 420)

                HStack(spacing: 4) {
                    Text("Follow the link to create api key?")
                        .foregroundStyle(.secondary)
                    Link("Link", destination: providerLink)
                        .foregroundStyle(.primary)
                }
                .font(.caption)
            }

            HStack(spacing: 12) {
                Button("Change provider") {
                    onBack()
                }
                .buttonStyle(.bordered)

                Button("Continue") {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Permissions Card

private struct PermissionsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 0) {
                content
                    .frame(maxWidth: .infinity)
                    .glassEffect(.regular.tint(.primary.opacity(0.05)), in: .rect(cornerRadius: 22))
            }
        } else {
            content
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(.primary.opacity(0.08), lineWidth: 0.5)
                )
        }
    }
}

private struct OnboardingPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 0) {
                content
                    .frame(maxWidth: .infinity)
                    .glassEffect(.regular.tint(.primary.opacity(0.05)), in: .rect(cornerRadius: 22))
            }
        } else {
            content
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(.primary.opacity(0.08), lineWidth: 0.5)
                )
        }
    }
}

// MARK: - Permission Row

private struct PermissionRow: View {
    let title: String
    let isGranted: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary)

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(isGranted ? "Granted" : "Not granted")")
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(permissionManager: PermissionManager()) {}
}
