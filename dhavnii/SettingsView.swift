//
//  SettingsView.swift
//  OpenWispher
//
//  Settings and preferences view with permission management and provider configuration.
//

import SwiftUI
import AVFoundation
import AppKit

// MARK: - Main Settings View

/// Settings window view with permission management and app preferences
internal struct SettingsView: View {
    internal var permissionManager: PermissionManager
    @Bindable internal var appState: AppState
    internal var historyManager: HistoryManager?
    
    @State private var showingResetAlert = false
    @SceneStorage("settings.selectedSection") private var selectedSectionRaw: String = SettingsSection.permissions.rawValue
    
    private enum SettingsSection: String, CaseIterable {
        case permissions = "Permissions"
        case providers = "Providers"
        case general = "General"
        case history = "History"
        case about = "About"
    }
    
    private var selectedSectionBinding: Binding<SettingsSection> {
        Binding(
            get: { SettingsSection(rawValue: selectedSectionRaw) ?? .permissions },
            set: { selectedSectionRaw = $0.rawValue }
        )
    }
    
    var body: some View {
        NavigationSplitView {
            List(selection: selectedSectionBinding) {
                Section("Settings") {
                    Label("Permissions", systemImage: "checkmark.shield.fill")
                        .tag(SettingsSection.permissions)
                    Label("Providers", systemImage: "network")
                        .tag(SettingsSection.providers)
                    Label("General", systemImage: "gear")
                        .tag(SettingsSection.general)
                    Label("History", systemImage: "clock.arrow.circlepath")
                        .tag(SettingsSection.history)
                    Label("About", systemImage: "info.circle.fill")
                        .tag(SettingsSection.about)
                }
            }
            .listStyle(.sidebar)
        } detail: {
            switch selectedSectionBinding.wrappedValue {
            case .permissions:
                PermissionsSettingsView(permissionManager: permissionManager)
            case .providers:
                ProvidersSettingsView()
            case .general:
                GeneralSettingsView(
                    showingResetAlert: $showingResetAlert,
                    appState: appState
                )
            case .history:
                HistorySettingsView(historyManager: historyManager)
            case .about:
                AboutSettingsView()
            }
        }
        .frame(minWidth: UIConstants.Window.settingsWidth, minHeight: UIConstants.Window.settingsHeight)
        .background(WindowConfigurator())
        .seamlessToolbarWindowBackground()
    }
}

// MARK: - Glass Card Component

private struct GlassCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer(spacing: 0) {
                content
                    .padding(UIConstants.Spacing.large)
                    .glassEffect(.regular.tint(.primary.opacity(0.05)), in: .rect(cornerRadius: 16))
            }
        } else {
            content
                .padding(UIConstants.Spacing.large)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.primary.opacity(0.1), lineWidth: 1)
                )
        }
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
                
                // Permission Cards
                VStack(spacing: UIConstants.Spacing.standard) {
                    PermissionCard(
                        icon: "mic.fill",
                        iconColor: .blue,
                        title: "Microphone",
                        description: "Used to capture your voice for transcription.",
                        isGranted: permissionManager.hasMicrophonePermission,
                        status: microphoneStatusText,
                        actionTitle: "Request Access",
                        action: {
                            Task {
                                await permissionManager.requestMicrophonePermission()
                            }
                        }
                    )
                    
                    PermissionCard(
                        icon: "hand.raised.fill",
                        iconColor: .purple,
                        title: "Accessibility",
                        description: "Allows auto-paste and global hotkey support.",
                        isGranted: permissionManager.hasAccessibilityPermission,
                        status: accessibilityStatusText,
                        actionTitle: "Open Settings",
                        action: {
                            permissionManager.requestAccessibilityPermission()
                        }
                    )
                }
                
                // Overall Status
                OverallStatusCard(hasAllPermissions: permissionManager.hasAllPermissions)
                    .animation(.easeInOut(duration: UIConstants.Animation.standard), value: permissionManager.hasAllPermissions)
                
                // Refresh Button
                HStack {
                    Text("Not seeing the correct status?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button(action: refreshPermissions) {
                        HStack(spacing: 4) {
                            Image(systemName: isCheckingPermissions ? "arrow.clockwise" : "arrow.clockwise")
                                .rotationEffect(.degrees(isCheckingPermissions ? 360 : 0))
                                .animation(isCheckingPermissions ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isCheckingPermissions)
                            Text("Refresh")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isCheckingPermissions)
                    .keyboardShortcut("r", modifiers: [.command])
                    .help("Re-check system permissions")
                }
            }
            .padding(.horizontal, UIConstants.Spacing.section)
            .padding(.bottom, UIConstants.Spacing.extraLarge)
        }
    }
    
    private var microphoneStatusText: String {
        permissionManager.hasMicrophonePermission ? "Granted" : "Required"
    }
    
    private var accessibilityStatusText: String {
        permissionManager.hasAccessibilityPermission ? "Granted" : "Required"
    }
    
    private func refreshPermissions() {
        isCheckingPermissions = true
        permissionManager.checkPermissions()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + UIConstants.Delay.permissionCheck) {
            isCheckingPermissions = false
        }
    }
}

// MARK: - Permission Card

private struct PermissionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let isGranted: Bool
    let status: String
    let actionTitle: String
    let action: () -> Void
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: UIConstants.Spacing.standard) {
                HStack(spacing: UIConstants.Spacing.standard) {
                    // Icon
                    ZStack {
                        if #available(iOS 26.0, macOS 26.0, *) {
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundStyle(iconColor)
                                .frame(width: 50, height: 50)
                                .glassEffect(.regular.tint(iconColor.opacity(0.15)), in: .rect(cornerRadius: 12))
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(iconColor.opacity(0.15))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .foregroundStyle(iconColor)
                                )
                        }
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
                
                // Action Button
                if !isGranted {
                    Button(action: action) {
                        HStack {
                            Image(systemName: "arrow.forward.circle.fill")
                            Text(actionTitle)
                            Spacer()
                        }
                        .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .padding(.top, UIConstants.Spacing.medium)
                }
            }
        }
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    let isGranted: Bool
    let text: String
    
    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(isGranted ? .green : .orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .glassEffect(
                    .regular
                    .tint(isGranted ? Color.green.opacity(0.15) : Color.orange.opacity(0.15)),
                    in: .capsule
                )
        } else {
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(isGranted ? .green : .orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill((isGranted ? Color.green : Color.orange).opacity(0.15))
                )
        }
    }
}

// MARK: - Overall Status Card

private struct OverallStatusCard: View {
    let hasAllPermissions: Bool
    
    var body: some View {
        GlassCard {
            HStack(spacing: UIConstants.Spacing.standard) {
                Image(systemName: hasAllPermissions ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(hasAllPermissions ? .green : .orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(hasAllPermissions ? "All permissions granted" : "Some permissions missing")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(hasAllPermissions ? .green : .orange)
                    
                    if !hasAllPermissions {
                        Text("Grant all permissions for full functionality")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Providers Settings Tab

private struct ProvidersSettingsView: View {
    @AppStorage("selectedTranscriptionProvider") private var selectedProviderRaw = TranscriptionProviderType.groq.rawValue
    @AppStorage("selectedTTSProvider") private var selectedTTSProviderRaw = TTSProviderType.groq.rawValue
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIConstants.Spacing.section) {
                // Header
                VStack(alignment: .leading, spacing: UIConstants.Spacing.medium) {
                    Text("Providers")
                        .font(.title2)
                        .bold()
                    
                    Text("Configure AI providers for speech-to-text and text-to-speech.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, UIConstants.Spacing.extraLarge)
                
                // Transcription Provider
                ProviderConfigurationCard(
                    title: "Speech-to-Text",
                    icon: "waveform",
                    iconColor: .blue,
                    providers: TranscriptionProviderType.allCases.map { ProviderItem(id: $0.rawValue, name: $0.displayName, description: $0.description) },
                    selectedProvider: $selectedProviderRaw,
                    getAPIKey: { provider in
                        guard let type = TranscriptionProviderType(rawValue: provider) else { return nil }
                        return SecureStorage.retrieveAPIKey(for: type)
                    },
                    setAPIKey: { provider, key in
                        guard let type = TranscriptionProviderType(rawValue: provider) else { return }
                        if key.isEmpty {
                            try? SecureStorage.deleteAPIKey(for: type)
                        } else {
                            try? SecureStorage.storeAPIKey(key, for: type)
                        }
                    },
                    deleteAPIKey: { provider in
                        guard let type = TranscriptionProviderType(rawValue: provider) else { return }
                        try? SecureStorage.deleteAPIKey(for: type)
                    }
                )
                
                // TTS Provider
                ProviderConfigurationCard(
                    title: "Text-to-Speech",
                    icon: "speaker.wave.2",
                    iconColor: .purple,
                    providers: TTSProviderType.allCases.map { ProviderItem(id: $0.rawValue, name: $0.displayName, description: "") },
                    selectedProvider: $selectedTTSProviderRaw,
                    getAPIKey: { provider in
                        guard let type = TTSProviderType(rawValue: provider) else { return nil }
                        return SecureStorage.retrieveTTSAPIKey(for: type)
                    },
                    setAPIKey: { provider, key in
                        guard let type = TTSProviderType(rawValue: provider) else { return }
                        if key.isEmpty {
                            try? SecureStorage.deleteTTSAPIKey(for: type)
                        } else {
                            try? SecureStorage.storeTTSAPIKey(key, for: type)
                        }
                    },
                    deleteAPIKey: { provider in
                        guard let type = TTSProviderType(rawValue: provider) else { return }
                        try? SecureStorage.deleteTTSAPIKey(for: type)
                    }
                )
            }
            .padding(.horizontal, UIConstants.Spacing.section)
            .padding(.bottom, UIConstants.Spacing.extraLarge)
        }
    }
}

// MARK: - Provider Item Model

private struct ProviderItem: Identifiable {
    let id: String
    let name: String
    let description: String
}

// MARK: - Provider Configuration Card

private struct ProviderConfigurationCard: View {
    let title: String
    let icon: String
    let iconColor: Color
    let providers: [ProviderItem]
    @Binding var selectedProvider: String
    let getAPIKey: (String) -> String?
    let setAPIKey: (String, String) -> Void
    let deleteAPIKey: (String) -> Void
    
    @State private var apiKeyText = ""
    @State private var isEditingAPIKey = false
    @State private var hasExistingKey = false
    
    private var selectedProviderItem: ProviderItem? {
        providers.first { $0.id == selectedProvider }
    }
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: UIConstants.Spacing.medium) {
                // Header with Icon
                HStack(spacing: UIConstants.Spacing.standard) {
                    ZStack {
                        if #available(iOS 26.0, macOS 26.0, *) {
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundStyle(iconColor)
                                .frame(width: 44, height: 44)
                                .glassEffect(.regular.tint(iconColor.opacity(0.15)), in: .rect(cornerRadius: 10))
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(iconColor.opacity(0.15))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: icon)
                                        .font(.title3)
                                        .foregroundStyle(iconColor)
                                )
                        }
                    }
                    
                    Text(title)
                        .font(.headline)
                    
                    Spacer()
                }
                
                // Provider Selector Dropdown
                VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
                    Text("Select Provider")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Menu {
                        ForEach(providers) { provider in
                            Button(provider.name) {
                                selectedProvider = provider.id
                                checkExistingKey()
                            }
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedProviderItem?.name ?? "Select...")
                                    .font(.subheadline.weight(.medium))
                                
                                Text(selectedProviderItem?.description ?? "")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, UIConstants.Spacing.standard)
                        .padding(.vertical, UIConstants.Spacing.medium)
                        .background(.background.opacity(0.3))
                        .cornerRadius(UIConstants.CornerRadius.medium)
                    }
                    .help("Choose your preferred provider")
                }
                
                // API Key Section
                if isEditingAPIKey {
                    // Edit Mode - Show text field
                    VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
                        Text("API Key")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        SecureField("Enter API key", text: $apiKeyText)
                            .textFieldStyle(.roundedBorder)
                            .padding(.vertical, 4)
                        
                        HStack {
                            Button("Cancel") {
                                isEditingAPIKey = false
                                apiKeyText = ""
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Spacer()
                            
                            Button("Save") {
                                setAPIKey(selectedProvider, apiKeyText)
                                isEditingAPIKey = false
                                hasExistingKey = !apiKeyText.isEmpty
                                apiKeyText = ""
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(apiKeyText.isEmpty)
                        }
                    }
                    .padding(.top, UIConstants.Spacing.small)
                } else {
                    // View Mode - Show status and action buttons
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: hasExistingKey ? "checkmark.seal.fill" : "key.slash")
                                .font(.caption)
                                .foregroundStyle(hasExistingKey ? .green : .secondary)
                            
                            Text(hasExistingKey ? "API key configured" : "No API key")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if hasExistingKey {
                            Menu {
                                Button("Update Key") {
                                    isEditingAPIKey = true
                                    apiKeyText = ""
                                }
                                
                                Button("Remove Key", role: .destructive) {
                                    deleteAPIKey(selectedProvider)
                                    hasExistingKey = false
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Button("Add API Key") {
                                isEditingAPIKey = true
                                apiKeyText = ""
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.top, UIConstants.Spacing.small)
                }
            }
        }
        .onAppear {
            checkExistingKey()
        }
        .onChange(of: selectedProvider) { oldValue, newValue in
            checkExistingKey()
            isEditingAPIKey = false
            apiKeyText = ""
        }
    }
    
    private func checkExistingKey() {
        let key = getAPIKey(selectedProvider)
        hasExistingKey = key != nil && !key!.isEmpty
    }
}

// MARK: - General Settings Tab

private struct GeneralSettingsView: View {
    @Binding var showingResetAlert: Bool
    var appState: AppState
    
    @AppStorage("autoLaunchEnabled") private var autoLaunchEnabled = false
    
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
                
                // Startup Settings
                GlassCard {
                    VStack(alignment: .leading, spacing: UIConstants.Spacing.medium) {
                        Text("Startup")
                            .font(.headline)
                        
                        Toggle(isOn: $autoLaunchEnabled) {
                            VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
                                Text("Launch at Login")
                                    .font(.subheadline)
                                Text("Automatically start when you log in")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                    }
                }
                
                // Hotkey Settings
                GlassCard {
                    VStack(alignment: .leading, spacing: UIConstants.Spacing.medium) {
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
                            .background(.background.opacity(0.3))
                            .cornerRadius(8)
                        }
                    }
                }
                
                // Status
                GlassCard {
                    VStack(alignment: .leading, spacing: UIConstants.Spacing.medium) {
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
                                Text("Last: Just now")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                // Advanced - Reset
                GlassCard {
                    VStack(alignment: .leading, spacing: UIConstants.Spacing.medium) {
                        Text("Advanced")
                            .font(.headline)
                        
                        Button(
                            role: .destructive,
                            action: { showingResetAlert = true }
                        ) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset App")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .keyboardShortcut("r", modifiers: [.command, .shift])
                        .help("Reset preferences and restart the app")
                    }
                }
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
            Text("This will clear all preferences and require you to complete onboarding again. Permissions will need to be re-granted.")
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
    
    private func resetApp() {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "autoLaunchEnabled")
        UserDefaults.standard.removeObject(forKey: "selectedTranscriptionProvider")
        UserDefaults.standard.synchronize()
        
        SecureStorage.clearAllAPIKeys()
        
        appState.hasCompletedOnboarding = false
        appState.lastTranscription = ""
        appState.recordingState = .idle
        
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - History Settings Tab

private struct HistorySettingsView: View {
    var historyManager: HistoryManager?
    
    @AppStorage("historyRetentionDays") private var retentionDays = 30
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
                
                // Retention Settings
                GlassCard {
                    VStack(alignment: .leading, spacing: UIConstants.Spacing.medium) {
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
                            .pickerStyle(.menu)
                            .onChange(of: retentionDays) { oldValue, newValue in
                                historyManager?.updateRetentionDays(newValue)
                            }
                            .help("Choose how long to keep transcriptions")
                            
                            Text("Transcriptions older than this period will be automatically deleted (except favorites).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Statistics
                GlassCard {
                    VStack(alignment: .leading, spacing: UIConstants.Spacing.medium) {
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
                }
                
                // Data Management
                GlassCard {
                    VStack(alignment: .leading, spacing: UIConstants.Spacing.medium) {
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
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .keyboardShortcut(.delete, modifiers: [.command, .shift])
                        .help("Permanently delete all transcriptions")
                    }
                }
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

// MARK: - About Settings Tab

private struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // App Icon
            if #available(iOS 26.0, macOS 26.0, *) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .glassEffect(.regular, in: .circle)
            } else {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
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
            if #available(iOS 26.0, macOS 26.0, *) {
                GlassEffectContainer(spacing: 12) {
                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(icon: "mic.fill", text: "Fast voice transcription")
                        FeatureRow(icon: "wand.and.stars", text: "Powered by Groq AI")
                        FeatureRow(icon: "keyboard.fill", text: "Auto-paste to any app")
                        FeatureRow(icon: "bolt.fill", text: "Global hotkey: ⌥ + Space")
                    }
                    .padding()
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                }
                .padding(.horizontal, 40)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(icon: "mic.fill", text: "Fast voice transcription")
                    FeatureRow(icon: "wand.and.stars", text: "Powered by Groq AI")
                    FeatureRow(icon: "keyboard.fill", text: "Auto-paste to any app")
                    FeatureRow(icon: "bolt.fill", text: "Global hotkey: ⌥ + Space")
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding(.horizontal, 40)
            }
            
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
