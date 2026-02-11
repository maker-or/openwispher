//
//  OnboardingView.swift
//  OpenWispher
//
//  First-launch onboarding flow with native macOS styling and liquid glass.
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Onboarding view for permission requests
struct OnboardingView: View {
    var permissionManager: PermissionManager
    var hotkeyManager: HotkeyManager?
    let onComplete: () -> Void

    @State private var currentStep: OnboardingStep = .welcome
    @State private var didAutoAdvance = false
    @State private var didAutoComplete = false
    @State private var apiKeyText = ""
    @State private var isRecordingHotkey = false
    @State private var hotkey = HotkeyDefinition.loadFromDefaults()
    @State private var isApplyingHotkey = false
    @AppStorage("selectedTranscriptionProvider") private var selectedProviderRaw =
        TranscriptionProviderType.groq.rawValue

    private enum OnboardingStep: Int, CaseIterable, Hashable {
        case welcome
        case provider
        case apiKey
        case permissions
        case hotkey
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
        .onChange(of: currentStep) { _, newValue in
            if newValue == .hotkey {
                hotkey = HotkeyDefinition.loadFromDefaults()
            }
        }
        .onChange(of: hotkey) { oldValue, newValue in
            guard oldValue != newValue else { return }
            if hotkeyManager?.currentHotkey == newValue {
                return
            }
            applyHotkeyChange(newValue)
        }
        .onChange(of: permissionManager.hasAllPermissions) { _, hasAllPermissions in
            guard currentStep == .permissions, hasAllPermissions, !didAutoComplete else { return }
            didAutoComplete = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    currentStep = .hotkey
                }
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
                permissionManager: permissionManager,
                onContinue: {
                    playChime()
                    withAnimation(.easeInOut(duration: 0.4)) {
                        currentStep = .hotkey
                    }
                }
            )
        case .hotkey:
            HotkeySetupScreen(
                hotkey: $hotkey,
                isRecordingHotkey: $isRecordingHotkey,
                onBack: {
                    playChime()
                    withAnimation(.easeInOut(duration: 0.35)) {
                        currentStep = .permissions
                    }
                },
                onContinue: {
                    playChime()
                    finishOnboarding()
                }
            )
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

    private func applyHotkeyChange(_ newHotkey: HotkeyDefinition) {
        guard !isApplyingHotkey else { return }
        isApplyingHotkey = true
        defer { isApplyingHotkey = false }

        guard let hotkeyManager = hotkeyManager else {
            newHotkey.saveToDefaults()
            return
        }

        if hotkeyManager.updateHotkey(newHotkey) {
            newHotkey.saveToDefaults()
        } else {
            FeedbackManager.shared.error(
                "Hotkey Unavailable",
                message: "That shortcut could not be registered. Try a different combination."
            )
            let fallback = hotkeyManager.currentHotkey
            hotkey = fallback
            fallback.saveToDefaults()
        }
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
    let onContinue: () -> Void

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
                Button("Continue") {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Continue")
            } else {
                Button("Continue Anyway") {
                    onContinue()
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
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
                    Link("Click Here", destination: providerLink)
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

private struct HotkeySetupScreen: View {
    @Binding var hotkey: HotkeyDefinition
    @Binding var isRecordingHotkey: Bool
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Set your shortcut")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.primary)

            VStack(spacing: 12) {
                OnboardingPanel {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Default")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(HotkeyDefinition.defaultHotkey.displayString)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)

                        Divider()
                            .opacity(0.2)

                        HStack {
                            Text("Current")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.secondary)

                            Spacer()

                            HotkeyRecorderControl(
                                hotkey: $hotkey,
                                isRecording: $isRecordingHotkey
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                    }
                }
                .frame(width: 420)

                Text("Click the shortcut to change it. Press Esc to cancel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button("Use Default") {
                    hotkey = .defaultHotkey
                }
                .buttonStyle(.bordered)

                Spacer()
                    .frame(width: 8)

                Button("Back") {
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
        content
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(.primary.opacity(0.08), lineWidth: 0.5)
            )
    }
}

private struct OnboardingPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(.primary.opacity(0.08), lineWidth: 0.5)
            )
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
    OnboardingView(permissionManager: PermissionManager(), hotkeyManager: nil) {}
}

// MARK: - Hotkey Recorder

private struct HotkeyRecorderControl: View {
    @Binding var hotkey: HotkeyDefinition
    @Binding var isRecording: Bool

    var body: some View {
        HStack(spacing: 6) {
            if isRecording {
                Text("Press shortcut")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            } else {
                Text(hotkey.displayString)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
        }
        .foregroundStyle(isRecording ? .primary : .secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(isRecording ? 0.12 : 0.06))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            isRecording = true
        }
        .help(isRecording ? "Press a shortcut, Esc to cancel" : "Click to set a shortcut")
        .background(
            HotkeyRecorderRepresentable(isRecording: $isRecording, hotkey: $hotkey)
                .frame(width: 0, height: 0)
        )
    }
}

private struct HotkeyRecorderRepresentable: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var hotkey: HotkeyDefinition

    func makeCoordinator() -> Coordinator {
        Coordinator(isRecording: $isRecording, hotkey: $hotkey)
    }

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.onHotkeyCaptured = { capturedHotkey in
            context.coordinator.capture(hotkey: capturedHotkey)
        }
        view.onCancel = {
            context.coordinator.cancel()
        }
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        nsView.isRecording = isRecording
    }

    final class Coordinator {
        @Binding var isRecording: Bool
        @Binding var hotkey: HotkeyDefinition

        init(isRecording: Binding<Bool>, hotkey: Binding<HotkeyDefinition>) {
            _isRecording = isRecording
            _hotkey = hotkey
        }

        func capture(hotkey: HotkeyDefinition) {
            self.hotkey = hotkey
            isRecording = false
        }

        func cancel() {
            isRecording = false
        }
    }
}

private final class HotkeyRecorderNSView: NSView {
    var isRecording: Bool = false {
        didSet {
            if isRecording {
                window?.makeFirstResponder(self)
            }
        }
    }

    var onHotkeyCaptured: ((HotkeyDefinition) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == UInt16(kVK_Escape) {
            isRecording = false
            onCancel?()
            return
        }

        let modifierFlags = event.modifierFlags
        let hasModifiers = modifierFlags.contains(.command)
            || modifierFlags.contains(.option)
            || modifierFlags.contains(.control)
            || modifierFlags.contains(.shift)

        guard hasModifiers else {
            FeedbackManager.shared.warning(
                "Shortcut needs modifiers",
                message: "Use Command, Option, Control, or Shift with a key."
            )
            return
        }

        let modifiers = HotkeyDefinition.modifiersFrom(flags: modifierFlags)
        let hotkey = HotkeyDefinition(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        onHotkeyCaptured?(hotkey)
    }
}
