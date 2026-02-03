//
//  SettingsView.swift
//  OpenWispher
//
//  Settings and preferences view with permission management.
//

import AVFoundation
import SwiftUI

/// Settings window view with permission management and app preferences
internal struct SettingsView: View {
    internal var permissionManager: PermissionManager
    @Bindable internal var appState: AppState
    internal var historyManager: HistoryManager?

    @State private var autoLaunchEnabled = false
    @State private var showingResetAlert = false
    @State private var showingAbout = false

    var body: some View {
        TabView {
            Tab("Permissions", systemImage: "checkmark.shield.fill") {
                PermissionsSettingsView(permissionManager: permissionManager)
            }

            Tab("General", systemImage: "gear") {
                GeneralSettingsView(
                    autoLaunchEnabled: $autoLaunchEnabled,
                    showingResetAlert: $showingResetAlert,
                    appState: appState
                )
            }

            Tab("History", systemImage: "clock.arrow.circlepath") {
                HistorySettingsView(historyManager: historyManager)
            }

            Tab("About", systemImage: "info.circle.fill") {
                AboutSettingsView()
            }
        }
        .frame(width: UIConstants.Window.settingsWidth, height: UIConstants.Window.settingsHeight)
        .onAppear {
            loadPreferences()
        }
        .background(WindowConfigurator())
        .seamlessToolbarWindowBackground()
    }

    private func loadPreferences() {
        autoLaunchEnabled = UserDefaults.standard.bool(forKey: "autoLaunchEnabled")
    }
}

// MARK: - Permissions Settings Tab

private struct PermissionsSettingsView: View {
    var permissionManager: PermissionManager
    @State private var isCheckingPermissions = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIConstants.Spacing.section) {
                // Header
                VStack(alignment: .leading, spacing: UIConstants.Spacing.medium) {
                    Text("Permissions")
                        .font(.title2)
                        .bold()

                    Text("OpenWispher requires these permissions to function properly.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, UIConstants.Spacing.extraLarge)

                Divider()

                // Permission Cards in Glass Container
                GlassEffectContainer(spacing: UIConstants.Spacing.standard) {
                    // Microphone Permission
                    PermissionCardView(
                        icon: "mic.fill",
                        iconColor: .blue,
                        title: "Microphone Access",
                        description: "Required to record your voice for transcription.",
                        isGranted: permissionManager.hasMicrophonePermission,
                        status: microphoneStatusText,
                        actionTitle: "Request Permission",
                        action: {
                            Task {
                                await permissionManager.requestMicrophonePermission()
                            }
                        }
                    )

                    // Accessibility Permission
                    PermissionCardView(
                        icon: "hand.raised.fill",
                        iconColor: .purple,
                        title: "Accessibility Access",
                        description:
                            "Required to auto-paste transcribed text and monitor global hotkeys.",
                        isGranted: permissionManager.hasAccessibilityPermission,
                        status: accessibilityStatusText,
                        actionTitle: "Request Permission",
                        action: {
                            permissionManager.requestAccessibilityPermission()
                        }
                    )
                }

                Divider()

                // Manual Refresh
                HStack {
                    Text("Not seeing the correct status?")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button(action: refreshPermissions) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .disabled(isCheckingPermissions)
                }

                // Overall Status
                if permissionManager.hasAllPermissions {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("All permissions granted")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular.tint(.green))
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Some permissions missing")
                                .font(.subheadline)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.orange)
                            Text("Grant all permissions for full functionality")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular.tint(.orange))
                }
            }
            .padding(.horizontal, UIConstants.Spacing.section)
            .padding(.bottom, UIConstants.Spacing.extraLarge)
        }
    }

    private var microphoneStatusText: String {
        permissionManager.hasMicrophonePermission ? "Granted" : "Not Granted"
    }

    private var accessibilityStatusText: String {
        permissionManager.hasAccessibilityPermission ? "Granted" : "Not Granted"
    }

    private func refreshPermissions() {
        isCheckingPermissions = true
        permissionManager.checkPermissions()

        // Small delay for UI feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + UIConstants.Delay.permissionCheck) {
            isCheckingPermissions = false
        }
    }
}

// MARK: - Permission Card Component

private struct PermissionCardView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let isGranted: Bool
    let status: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.standard) {
            HStack(spacing: UIConstants.Spacing.standard) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(iconColor)
                }

                // Title and Description
                VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
                    Text(title)
                        .font(.headline)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Status Badge
                StatusBadge(isGranted: isGranted, text: status)
            }

            // Action Button - Only shown when not granted, visually separate
            if !isGranted {
                Divider()
                    .padding(.vertical, UIConstants.Spacing.medium)
                
                Button(action: action) {
                    HStack(spacing: UIConstants.Spacing.medium) {
                        Image(systemName: "arrow.forward.circle.fill")
                            .font(.title3)
                        Text(actionTitle)
                            .font(.subheadline)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                    .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(UIConstants.Spacing.large)
        .glassEffect(.regular)
    }
}

// MARK: - Status Badge Component

private struct StatusBadge: View {
    let isGranted: Bool
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption)
            Text(text)
                .font(.caption)
                .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(isGranted ? .green : .orange)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill((isGranted ? Color.green : Color.orange).opacity(0.15))
        )
    }
}

// MARK: - General Settings Tab

private struct GeneralSettingsView: View {
    @Binding var autoLaunchEnabled: Bool
    @Binding var showingResetAlert: Bool
    var appState: AppState
    
    @State private var selectedProvider: TranscriptionProviderType = .groq
    @State private var groqAPIKey: String = ""
    @State private var elevenLabsAPIKey: String = ""
    @State private var deepgramAPIKey: String = ""
    @State private var showAPIKey: Bool = false
    @State private var selectedTTSProvider: TTSProviderType = .groq
    @State private var openAIAPIKey: String = ""
    @State private var showTTSAPIKey: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIConstants.Spacing.section) {
                // Header
                VStack(alignment: .leading, spacing: UIConstants.Spacing.medium) {
                    Text("General")
                        .font(.title2)
                        .bold()

                    Text("Configure app behavior and preferences.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, UIConstants.Spacing.extraLarge)

                Divider()

                // Startup Settings
                VStack(alignment: .leading, spacing: UIConstants.Spacing.large) {
                    Text("Startup")
                        .font(.headline)

                    Toggle(isOn: $autoLaunchEnabled) {
                        VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
                            Text("Launch at Login")
                                .font(.subheadline)
                            Text("Automatically start OpenWispher when you log in")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .onChange(of: autoLaunchEnabled) { oldValue, newValue in
                        UserDefaults.standard.set(newValue, forKey: "autoLaunchEnabled")
                        // TODO: Implement actual launch agent configuration
                    }
                }
                .padding()
                .glassEffect(.regular)

                // Hotkey Settings
                VStack(alignment: .leading, spacing: UIConstants.Spacing.large) {
                    Text("Hotkey")
                        .font(.headline)

                    HStack {
                        VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
                            Text("Global Hotkey")
                                .font(.subheadline)
                            Text("Press to start/stop recording")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Text("⌥")
                                .font(.system(size: 18, weight: .medium))
                            Text("+")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Space")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .glassEffect(.regular)
                    }
                }
                .padding()
                .glassEffect(.regular)

                // Transcription Provider Settings
                VStack(alignment: .leading, spacing: UIConstants.Spacing.large) {
                    Text("Transcription Provider")
                        .font(.headline)
                    
                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(TranscriptionProviderType.allCases) { provider in
                            Text(provider.displayName)
                                .tag(provider)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .onChange(of: selectedProvider) { oldValue, newValue in
                        UserDefaults.standard.set(newValue.rawValue, forKey: "selectedTranscriptionProvider")
                        showAPIKey = false
                    }
                    
                    // Provider description
                    Text(selectedProvider.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // API Key input for selected provider
                    VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
                        Text("\(selectedProvider.rawValue) API Key")
                            .font(.subheadline)
                        
                        HStack(spacing: UIConstants.Spacing.medium) {
                            Group {
                                if showAPIKey {
                                    TextField("Enter API key", text: selectedAPIKeyBinding)
                                } else {
                                    SecureField("Enter API key", text: selectedAPIKeyBinding)
                                }
                            }
                            .textFieldStyle(.roundedBorder)
                            
                            Button {
                                showAPIKey.toggle()
                                if showAPIKey {
                                    loadTranscriptionKeysFromKeychain()
                                }
                            } label: {
                                Image(systemName: showAPIKey ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.plain)
                            .help(showAPIKey ? "Hide API key" : "Show API key")
                        }
                    }
                    .padding()
                    .glassEffect(.regular.interactive())
                }
                .padding()
                .glassEffect(.regular)

                // Text-to-Speech Provider Settings
                VStack(alignment: .leading, spacing: UIConstants.Spacing.large) {
                    Text("Text-to-Speech Provider")
                        .font(.headline)

                    Picker("Provider", selection: $selectedTTSProvider) {
                        ForEach(TTSProviderType.allCases) { provider in
                            Text(provider.displayName)
                                .tag(provider)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .onChange(of: selectedTTSProvider) { _, newValue in
                        UserDefaults.standard.set(newValue.rawValue, forKey: "selectedTTSProvider")
                        showTTSAPIKey = false
                    }

                    // API Key input for selected provider (OpenAI has separate key)
                    VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
                        Text("\(selectedTTSProvider.rawValue) API Key")
                            .font(.subheadline)

                        HStack(spacing: UIConstants.Spacing.medium) {
                            Group {
                                if showTTSAPIKey {
                                    TextField("Enter API key", text: selectedTTSAPIKeyBinding)
                                } else {
                                    SecureField("Enter API key", text: selectedTTSAPIKeyBinding)
                                }
                            }
                            .textFieldStyle(.roundedBorder)

                            Button {
                                showTTSAPIKey.toggle()
                                if showTTSAPIKey {
                                    loadTTSKeysFromKeychain()
                                }
                            } label: {
                                Image(systemName: showTTSAPIKey ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.plain)
                            .help(showTTSAPIKey ? "Hide API key" : "Show API key")
                        }
                    }
                    .padding()
                    .glassEffect(.regular.interactive())
                }
                .padding()
                .glassEffect(.regular)

                // Status
                VStack(alignment: .leading, spacing: UIConstants.Spacing.large) {
                    Text("Status")
                        .font(.headline)

                    HStack {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)

                        Text(statusText)
                            .font(.subheadline)

                        Spacer()

                        if !appState.lastTranscription.isEmpty {
                            Text("Last: \(timeAgo)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .glassEffect(.regular)

                Divider()

                // Advanced
                VStack(alignment: .leading, spacing: UIConstants.Spacing.large) {
                    Text("Advanced")
                        .font(.headline)

                    Button(
                        role: .destructive,
                        action: {
                            showingResetAlert = true
                        }
                    ) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset App")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                }
                .padding()
                .glassEffect(.regular)
            }
            .padding(.horizontal, UIConstants.Spacing.section)
            .padding(.bottom, UIConstants.Spacing.extraLarge)
        }
        .alert("Reset Application", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetApp()
            }
        } message: {
            Text(
                "This will clear all preferences and require you to complete onboarding again. Permissions will need to be re-granted."
            )
        }
        .onAppear {
            loadTranscriptionSettings()
        }
    }
    
    private func loadTranscriptionSettings() {
        // Load selected provider
        if let savedProvider = UserDefaults.standard.string(forKey: "selectedTranscriptionProvider"),
           let provider = TranscriptionProviderType(rawValue: savedProvider) {
            selectedProvider = provider
        }

        // Load selected TTS provider
        if let savedTTSProvider = UserDefaults.standard.string(forKey: "selectedTTSProvider"),
           let ttsProvider = TTSProviderType(rawValue: savedTTSProvider) {
            selectedTTSProvider = ttsProvider
        }
    }

    private func loadTranscriptionKeysFromKeychain() {
        groqAPIKey = SecureStorage.retrieveAPIKey(for: .groq) ?? ""
        elevenLabsAPIKey = SecureStorage.retrieveAPIKey(for: .elevenLabs) ?? ""
        deepgramAPIKey = SecureStorage.retrieveAPIKey(for: .deepgram) ?? ""
    }

    private func loadTTSKeysFromKeychain() {
        openAIAPIKey = SecureStorage.retrieveTTSAPIKey(for: .openAI) ?? ""
    }

    private var selectedAPIKeyBinding: Binding<String> {
        switch selectedProvider {
        case .groq:
            return Binding(
                get: { groqAPIKey },
                set: { newValue in
                    groqAPIKey = newValue
                    if newValue.isEmpty {
                        try? SecureStorage.deleteAPIKey(for: .groq)
                    } else {
                        try? SecureStorage.storeAPIKey(newValue, for: .groq)
                    }
                }
            )
        case .elevenLabs:
            return Binding(
                get: { elevenLabsAPIKey },
                set: { newValue in
                    elevenLabsAPIKey = newValue
                    if newValue.isEmpty {
                        try? SecureStorage.deleteAPIKey(for: .elevenLabs)
                    } else {
                        try? SecureStorage.storeAPIKey(newValue, for: .elevenLabs)
                    }
                }
            )
        case .deepgram:
            return Binding(
                get: { deepgramAPIKey },
                set: { newValue in
                    deepgramAPIKey = newValue
                    if newValue.isEmpty {
                        try? SecureStorage.deleteAPIKey(for: .deepgram)
                    } else {
                        try? SecureStorage.storeAPIKey(newValue, for: .deepgram)
                    }
                }
            )
        }
    }

    private var selectedTTSAPIKeyBinding: Binding<String> {
        switch selectedTTSProvider {
        case .groq:
            return Binding(
                get: { groqAPIKey },
                set: { newValue in
                    groqAPIKey = newValue
                    if newValue.isEmpty {
                        try? SecureStorage.deleteAPIKey(for: .groq)
                    } else {
                        try? SecureStorage.storeAPIKey(newValue, for: .groq)
                    }
                }
            )
        case .elevenLabs:
            return Binding(
                get: { elevenLabsAPIKey },
                set: { newValue in
                    elevenLabsAPIKey = newValue
                    if newValue.isEmpty {
                        try? SecureStorage.deleteAPIKey(for: .elevenLabs)
                    } else {
                        try? SecureStorage.storeAPIKey(newValue, for: .elevenLabs)
                    }
                }
            )
        case .deepgram:
            return Binding(
                get: { deepgramAPIKey },
                set: { newValue in
                    deepgramAPIKey = newValue
                    if newValue.isEmpty {
                        try? SecureStorage.deleteAPIKey(for: .deepgram)
                    } else {
                        try? SecureStorage.storeAPIKey(newValue, for: .deepgram)
                    }
                }
            )
        case .openAI:
            return Binding(
                get: { openAIAPIKey },
                set: { newValue in
                    openAIAPIKey = newValue
                    if newValue.isEmpty {
                        try? SecureStorage.deleteTTSAPIKey(for: .openAI)
                    } else {
                        try? SecureStorage.storeTTSAPIKey(newValue, for: .openAI)
                    }
                }
            )
        }
    }

    private var statusColor: Color {
        switch appState.recordingState {
        case .idle: return .green
        case .recording: return .red
        case .processing: return .orange
        case .success: return .green
        case .error: return .red
        }
    }

    private var statusText: String {
        switch appState.recordingState {
        case .idle: return "Ready"
        case .recording: return "Recording..."
        case .processing: return "Processing..."
        case .success: return "Success!"
        case .error(let msg): return "Error: \(msg)"
        }
    }

    private var timeAgo: String {
        // Placeholder - would need to track timestamp
        "Just now"
    }

    private func resetApp() {
        // Clear all user defaults
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "autoLaunchEnabled")
        UserDefaults.standard.removeObject(forKey: "selectedTranscriptionProvider")
        UserDefaults.standard.synchronize()
        
        // Clear all API keys from secure Keychain storage
        SecureStorage.clearAllAPIKeys()

        // Reset app state
        appState.hasCompletedOnboarding = false
        appState.lastTranscription = ""
        appState.recordingState = .idle

        // Restart app
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - About Tab

private struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App Icon
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.pink, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // App Name and Version
            VStack(spacing: 4) {
                Text("OpenWispher")
                    .font(.title)
                    .bold()

                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Speech-to-Text, Instantly")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()
                .padding(.horizontal, 60)

            // Features
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "mic.fill", text: "Fast voice transcription")
                FeatureRow(icon: "wand.and.stars", text: "Powered by Groq AI")
                FeatureRow(icon: "keyboard.fill", text: "Auto-paste to any app")
                FeatureRow(icon: "bolt.fill", text: "Global hotkey: ⌥ + Space")
            }
            .padding()
            .glassEffect(.regular)
            .padding(.horizontal, 40)

            Spacer()

            // Links
            HStack(spacing: 20) {
                Button("GitHub") {
                    if let url = URL(string: "https://github.com") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)

                Button("Support") {
                    if let url = URL(string: "mailto:support@openwispher.app") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
            }
            .font(.caption)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - History Settings Tab

private struct HistorySettingsView: View {
    var historyManager: HistoryManager?
    
    @State private var retentionDays = 30
    @State private var transcriptionCount = 0
    @State private var showingClearAllAlert = false
    
    private let retentionOptions = [7, 14, 30, 60, 90]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIConstants.Spacing.section) {
                // Header
                VStack(alignment: .leading, spacing: UIConstants.Spacing.medium) {
                    Text("History")
                        .font(.title2)
                        .bold()
                    
                    Text("Manage transcription history retention and storage.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, UIConstants.Spacing.extraLarge)
                
                Divider()
                
                // Retention Settings
                VStack(alignment: .leading, spacing: UIConstants.Spacing.large) {
                    Text("Retention Period")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: UIConstants.Spacing.medium) {
                        Text("Keep transcriptions for")
                            .font(.subheadline)
                        
                        Picker("Retention Days", selection: $retentionDays) {
                            ForEach(retentionOptions, id: \.self) { days in
                                Text("\(days) days").tag(days)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: retentionDays) { oldValue, newValue in
                            historyManager?.updateRetentionDays(newValue)
                        }
                        
                        Text("Transcriptions older than this period will be automatically deleted (except favorites).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .glassEffect(.regular)
                
                // Statistics
                VStack(alignment: .leading, spacing: UIConstants.Spacing.large) {
                    Text("Statistics")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
                            Text("Total Transcriptions")
                                .font(.subheadline)
                            Text("\(transcriptionCount)")
                                .font(.title2)
                                .bold()
                        }
                        
                        Spacer()
                        
                        Image(systemName: "doc.text.fill")
                            .font(.title2)
                            .foregroundStyle(.tint)
                    }
                }
                .padding()
                .glassEffect(.regular)
                
                Divider()
                
                // Data Management
                VStack(alignment: .leading, spacing: UIConstants.Spacing.large) {
                    Text("Data Management")
                        .font(.headline)
                    
                    Button(role: .destructive) {
                        showingClearAllAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear All History")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                }
                .padding()
                .glassEffect(.regular)
            }
            .padding(.horizontal, UIConstants.Spacing.section)
            .padding(.bottom, UIConstants.Spacing.extraLarge)
        }
        .alert("Clear All History?", isPresented: $showingClearAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clearAllHistory()
            }
        } message: {
            Text("This will permanently delete all transcriptions from history. Favorites will also be deleted.")
        }
        .onAppear {
            loadHistorySettings()
        }
    }
    
    private func loadHistorySettings() {
        transcriptionCount = historyManager?.getTranscriptionCount() ?? 0
    }
    
    private func clearAllHistory() {
        historyManager?.deleteAllTranscriptions()
        transcriptionCount = 0
    }
}

// MARK: - Feature Row Component

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                            .foregroundStyle(.tint)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView(
        permissionManager: PermissionManager(),
        appState: AppState(),
        historyManager: nil
    )
}
