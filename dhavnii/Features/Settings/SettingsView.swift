//
//  SettingsView.swift
//  OpenWispher
//
//  Settings view with native macOS styling and liquid glass effects.
//

import AVFoundation
import AppKit
import Carbon.HIToolbox
import SwiftUI

// MARK: - Main Settings View

internal struct SettingsView: View {
    internal var permissionManager: PermissionManager
    @Bindable internal var appState: AppState
    @Binding internal var hotkeyManager: HotkeyManager?
    internal var historyManager: HistoryManager?

    @State private var showingResetAlert = false
    @State private var selectedSection: SettingsSection = .permissions

    private enum SettingsSection: String, CaseIterable, Identifiable {
        case permissions = "Permissions"
        case providers = "Providers"
        case general = "General"
        case history = "History"
        case about = "About"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .permissions: return "checkmark.shield"
            case .providers: return "bolt.horizontal"
            case .general: return "gearshape"
            case .history: return "clock"
            case .about: return "info.circle"
            }
        }

        var iconGradient: [Color] {
            switch self {
            case .permissions:
                return [
                    Color(red: 0.20, green: 0.78, blue: 0.55),
                    Color(red: 0.08, green: 0.55, blue: 0.45),
                ]
            case .providers:
                return [
                    Color(red: 0.25, green: 0.62, blue: 0.98),
                    Color(red: 0.10, green: 0.42, blue: 0.90),
                ]
            case .general:
                return [
                    Color(red: 0.98, green: 0.63, blue: 0.24),
                    Color(red: 0.92, green: 0.42, blue: 0.20),
                ]
            case .history:
                return [
                    Color(red: 0.56, green: 0.45, blue: 0.98),
                    Color(red: 0.35, green: 0.30, blue: 0.88),
                ]
            case .about:
                return [
                    Color(red: 0.94, green: 0.38, blue: 0.58),
                    Color(red: 0.84, green: 0.22, blue: 0.44),
                ]
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailView
                .background(.ultraThinMaterial.opacity(0.3))
        }
        .frame(minWidth: 750, minHeight: 550)
        .background(WindowConfigurator())
        .seamlessToolbarWindowBackground()
        .preferredColorScheme(.dark)
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // Header - matching HomeView style
            VStack(spacing: 8) {

                Text("Settings")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Navigation Items
            List(selection: $selectedSection) {
                Section {
                    ForEach(SettingsSection.allCases) { section in
                        settingsSidebarItem(for: section)
                            .tag(section)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Spacer()

            // Bottom info
            VStack(spacing: 12) {
                Divider()
                    .padding(.horizontal, 16)

                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)

                    Text("OpenWispher v1.0")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .frame(minWidth: 220)
        .background(.ultraThinMaterial)
    }

    private func settingsSidebarItem(for section: SettingsSection) -> some View {
        HStack(spacing: 10) {
            SidebarIconTile(systemName: section.icon, colors: section.iconGradient)

            Text(section.rawValue)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    selectedSection == section
                        ? Color.white.opacity(0.10)
                        : Color.clear
                )
                .padding(.horizontal, 6)
        )
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedSection {
        case .permissions:
            PermissionsSettingsView(permissionManager: permissionManager)
        case .providers:
            ProvidersSettingsView()
        case .general:
            GeneralSettingsView(
                showingResetAlert: $showingResetAlert,
                appState: appState,
                hotkeyManager: hotkeyManager
            )
        case .history:
            HistorySettingsView(historyManager: historyManager)
        case .about:
            AboutSettingsView()
        }
    }
}

// MARK: - Settings Section Container

private struct SettingsSectionContainer<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                content
            }
            .padding(32)
        }
    }
}

// MARK: - Settings Row

private struct SettingsRow<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String?
    let content: Content

    init(icon: String, title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content)
    {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            // Labels
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            content
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }
}

// MARK: - Settings Group

private struct SettingsGroup<Content: View>: View {
    let title: String?
    let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .padding(.leading, 4)
            }

            VStack(spacing: 1) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Permissions Settings

private struct PermissionsSettingsView: View {
    var permissionManager: PermissionManager
    @State private var isRefreshing = false

    var body: some View {
        SettingsSectionContainer(
            title: "Permissions",
            subtitle: "OpenWispher requires these permissions to function properly."
        ) {
            VStack(spacing: 20) {
                // Microphone
                PermissionRow(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "Capture voice for transcription",
                    isGranted: permissionManager.hasMicrophonePermission,
                    actionLabel: "Request Access",
                    action: {
                        Task {
                            await permissionManager.requestMicrophonePermission()
                        }
                    }
                )

                // Accessibility
                PermissionRow(
                    icon: "hand.raised.fill",
                    title: "Accessibility",
                    description: "Auto-paste and global hotkey",
                    isGranted: permissionManager.hasAccessibilityPermission,
                    actionLabel: "Open Settings",
                    action: {
                        permissionManager.requestAccessibilityPermission()
                    }
                )

                // Status Summary
                HStack(spacing: 12) {
                    Image(
                        systemName: permissionManager.hasAllPermissions
                            ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                    )
                    .font(.system(size: 16))
                    .foregroundStyle(permissionManager.hasAllPermissions ? .green : .orange)

                    Text(
                        permissionManager.hasAllPermissions
                            ? "All permissions granted" : "Some permissions required"
                    )
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        refresh()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                                .animation(
                                    isRefreshing
                                        ? .linear(duration: 1).repeatForever(autoreverses: false)
                                        : .default, value: isRefreshing)
                            Text("Refresh")
                        }
                        .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                )
            }
        }
    }

    private func refresh() {
        isRefreshing = true
        permissionManager.checkPermissions()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isRefreshing = false
        }
    }
}

// MARK: - Permission Row

private struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let actionLabel: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Icon Container
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 40, height: 40)

                    Image(systemName: isGranted ? "checkmark" : icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(isGranted ? .green : .primary)
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)

                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Status
                HStack(spacing: 4) {
                    Circle()
                        .fill(isGranted ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)

                    Text(isGranted ? "Granted" : "Required")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isGranted ? .green : .orange)
                }
            }
            .padding(16)

            // Action Button
            if !isGranted {
                Divider()
                    .padding(.horizontal, 16)

                Button(action: action) {
                    HStack {
                        Text(actionLabel)
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(.primary)
                    .padding(14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainNoFocusButtonStyle())
                .background(Color.primary.opacity(0.03))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }
}

// MARK: - Providers Settings

private struct ProvidersSettingsView: View {
    @AppStorage("selectedTranscriptionProvider") private var selectedProviderRaw =
        TranscriptionProviderType.groq.rawValue

    var body: some View {
        SettingsSectionContainer(
            title: "Providers",
            subtitle: "Configure AI providers for transcription and speech."
        ) {
            VStack(spacing: 24) {
                // Speech-to-Text
                ProviderCard(
                    title: "Speech-to-Text",
                    icon: "waveform",
                    providers: TranscriptionProviderType.allCases.map {
                        ($0.rawValue, $0.displayName, $0.description)
                    },
                    selectedProvider: $selectedProviderRaw,
                    getAPIKey: { provider in
                        guard let type = TranscriptionProviderType(rawValue: provider) else {
                            return nil
                        }
                        return SecureStorage.retrieveAPIKey(for: type)
                    },
                    setAPIKey: { provider, key in
                        guard let type = TranscriptionProviderType(rawValue: provider) else {
                            return
                        }
                        if key.isEmpty {
                            try? SecureStorage.deleteAPIKey(for: type)
                        } else {
                            try? SecureStorage.storeAPIKey(key, for: type)
                        }
                    },
                    deleteAPIKey: { provider in
                        guard let type = TranscriptionProviderType(rawValue: provider) else {
                            return
                        }
                        try? SecureStorage.deleteAPIKey(for: type)
                    }
                )

            }
        }
    }
}

// MARK: - Provider Card

private struct ProviderCard: View {
    let title: String
    let icon: String
    let providers: [(id: String, name: String, description: String)]
    @Binding var selectedProvider: String
    let getAPIKey: (String) -> String?
    let setAPIKey: (String, String) -> Void
    let deleteAPIKey: (String) -> Void

    @State private var apiKeyText = ""
    @State private var isEditing = false
    @State private var hasKey = false

    private var selectedName: String {
        providers.first { $0.id == selectedProvider }?.name ?? "Select"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(16)

            Divider()
                .padding(.horizontal, 16)

            // Provider Selection
            HStack {
                Text("Provider")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Spacer()

                Menu {
                    ForEach(providers, id: \.id) { provider in
                        Button(provider.name) {
                            selectedProvider = provider.id
                            checkKey()
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedName)
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
                }
                .menuStyle(.borderlessButton)
            }
            .padding(16)

            Divider()
                .padding(.horizontal, 16)

            // API Key
            if isEditing {
                VStack(spacing: 12) {
                    SecureField("Enter API Key", text: $apiKeyText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )

                    HStack {
                        Button("Cancel") {
                            isEditing = false
                            apiKeyText = ""
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Spacer()

                        Button("Save") {
                            setAPIKey(selectedProvider, apiKeyText)
                            isEditing = false
                            hasKey = !apiKeyText.isEmpty
                            apiKeyText = ""
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(apiKeyText.isEmpty)
                    }
                }
                .padding(16)
            } else {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: hasKey ? "checkmark.circle.fill" : "key")
                            .font(.system(size: 12))
                            .foregroundStyle(hasKey ? .green : .secondary)

                        Text(hasKey ? "API key configured" : "No API key")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if hasKey {
                        Menu {
                            Button("Update Key") {
                                isEditing = true
                            }
                            Button("Remove Key", role: .destructive) {
                                deleteAPIKey(selectedProvider)
                                hasKey = false
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                    } else {
                        Button("Add Key") {
                            isEditing = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
        .onAppear { checkKey() }
        .onChange(of: selectedProvider) { _, _ in
            checkKey()
            isEditing = false
            apiKeyText = ""
        }
    }

    private func checkKey() {
        let key = getAPIKey(selectedProvider)
        hasKey = key != nil && !key!.isEmpty
    }
}

// MARK: - General Settings

private struct GeneralSettingsView: View {
    @Binding var showingResetAlert: Bool
    var appState: AppState
    var hotkeyManager: HotkeyManager?

    @AppStorage("autoLaunchEnabled") private var autoLaunchEnabled = false
    @State private var isRecordingHotkey = false
    @State private var hotkey = HotkeyDefinition.loadFromDefaults()
    @State private var isApplyingHotkey = false

    var body: some View {
        SettingsSectionContainer(
            title: "General",
            subtitle: "Configure app behavior and preferences."
        ) {
            VStack(spacing: 20) {
                // Startup
                SettingsGroup(title: "Startup") {
                    SettingsRow(
                        icon: "power", title: "Launch at Login",
                        subtitle: "Start automatically when you log in"
                    ) {
                        Toggle("", isOn: $autoLaunchEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                }

                // Hotkey
                SettingsGroup(title: "Hotkey") {
                    SettingsRow(
                        icon: "keyboard", title: "Global Shortcut",
                        subtitle: "Start and stop recording"
                    ) {
                        HotkeyRecorderControl(
                            hotkey: $hotkey,
                            isRecording: $isRecordingHotkey
                        )
                    }
                }

                // Status
                SettingsGroup(title: "Status") {
                    SettingsRow(icon: "circle.fill", title: statusText, subtitle: nil) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                    }
                }

                // Advanced
                SettingsGroup(title: "Advanced") {
                    VStack(spacing: 0) {
                        SettingsRow(
                            icon: "sparkles", title: "Show Onboarding",
                            subtitle: "Start onboarding on next launch"
                        ) {
                            Button("Start Onboarding") {
                                UserDefaults.standard.set(true, forKey: "forceOnboardingOnLaunch")
                                NSApplication.shared.terminate(nil)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        SettingsRow(
                            icon: "arrow.counterclockwise", title: "Reset App",
                            subtitle: "Clear all settings and data"
                        ) {
                            Button("Reset", role: .destructive) {
                                showingResetAlert = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .alert("Reset Application?", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetApp()
            }
        } message: {
            Text("This will clear all preferences and require you to complete onboarding again.")
        }
        .onAppear {
            hotkey = HotkeyDefinition.loadFromDefaults()
        }
        .onChange(of: hotkey) { _, newValue in
            applyHotkeyChange(newValue)
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
        case .recording: return "Recording"
        case .processing: return "Processing"
        case .success: return "Success"
        case .error: return "Error"
        }
    }

    private func resetApp() {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "autoLaunchEnabled")
        UserDefaults.standard.removeObject(forKey: "selectedTranscriptionProvider")
        UserDefaults.standard.removeObject(forKey: HotkeyDefinition.keyCodeDefaultsKey)
        UserDefaults.standard.removeObject(forKey: HotkeyDefinition.modifiersDefaultsKey)
        UserDefaults.standard.synchronize()

        SecureStorage.clearAllAPIKeys()

        appState.hasCompletedOnboarding = false
        appState.lastTranscription = ""
        appState.recordingState = .idle

        NSApplication.shared.terminate(nil)
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

// MARK: - History Settings

private struct HistorySettingsView: View {
    var historyManager: HistoryManager?

    @AppStorage("historyRetentionDays") private var retentionDays = 30
    @State private var count = 0
    @State private var showingClearAlert = false

    private let retentionOptions = [7, 14, 30, 60, 90]

    var body: some View {
        SettingsSectionContainer(
            title: "History",
            subtitle: "Manage transcription history and storage."
        ) {
            VStack(spacing: 20) {
                // Retention
                SettingsGroup(title: "Retention") {
                    SettingsRow(
                        icon: "calendar", title: "Keep History", subtitle: "Older items auto-delete"
                    ) {
                        Menu {
                            ForEach(retentionOptions, id: \.self) { days in
                                Button("\(days) days") {
                                    retentionDays = days
                                    historyManager?.updateRetentionDays(days)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("\(retentionDays) days")
                                    .font(.system(size: 13))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.primary.opacity(0.06))
                            )
                        }
                        .menuStyle(.borderlessButton)
                    }
                }

                // Statistics
                SettingsGroup(title: "Storage") {
                    SettingsRow(icon: "doc.text", title: "Transcriptions", subtitle: nil) {
                        Text("\(count)")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                }

                // Clear
                SettingsGroup(title: "Data") {
                    SettingsRow(
                        icon: "trash", title: "Clear History", subtitle: "Delete all transcriptions"
                    ) {
                        Button("Clear All", role: .destructive) {
                            showingClearAlert = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .alert("Clear All History?", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                historyManager?.deleteAllTranscriptions()
                count = 0
            }
        } message: {
            Text("This will permanently delete all transcriptions.")
        }
        .onAppear {
            count = historyManager?.getTranscriptionCount() ?? 0
        }
    }
}

// MARK: - About Settings

private struct AboutSettingsView: View {
    @State private var updateManager = UpdateManager()
    @State private var hasAutoCheckedUpdates = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // App Icon
            VStack(spacing: 16) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 4) {
                    Text("OpenWispher")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Version \(updateManager.currentVersion)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
                .frame(height: 40)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Software Updates")
                            .font(.headline)
                        Text(updateManager.statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if updateManager.isChecking {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                HStack(spacing: 10) {
                    Button("Check for Updates") {
                        Task {
                            await updateManager.checkForUpdates()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(updateManager.isChecking)

                    if updateManager.updateAvailable {
                        Button("Download Latest DMG") {
                            updateManager.openDownloadURL()
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if updateManager.notesURL != nil {
                        Button("Release Notes") {
                            updateManager.openReleaseNotes()
                        }
                        .buttonStyle(.link)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
            .padding(.horizontal, 60)

            Spacer()
                .frame(height: 24)

            // Features
            VStack(spacing: 12) {
                FeatureRow(icon: "mic.fill", text: "Voice transcription")
                FeatureRow(icon: "bolt.fill", text: "Powered by Groq AI")
                FeatureRow(icon: "keyboard", text: "Auto-paste anywhere")
                FeatureRow(
                    icon: "command",
                    text: "Global hotkey: \(HotkeyDefinition.loadFromDefaults().displayString)"
                )
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
            .padding(.horizontal, 60)

            Spacer()

            // Links
            HStack(spacing: 24) {
                Link("GitHub", destination: URL(string: "https://github.com")!)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Link("Support", destination: URL(string: "mailto:support@openwispher.app")!)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial.opacity(0.3))
        .task {
            guard !hasAutoCheckedUpdates else { return }
            hasAutoCheckedUpdates = true
            await updateManager.checkForUpdates()
        }
    }
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
                DispatchQueue.main.async { [weak self] in
                    self?.window?.makeFirstResponder(self)
                }
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
            onCancel?()
            return
        }

        let modifierFlags = event.modifierFlags.intersection([.command, .option, .shift, .control])
        if modifierFlags.isEmpty {
            FeedbackManager.shared.warning(
                "Modifier Required",
                message: "Use Command, Option, Control, or Shift with a key."
            )
            return
        }

        let modifiers = HotkeyDefinition.modifiersFrom(flags: modifierFlags)
        let hotkey = HotkeyDefinition(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        onHotkeyCaptured?(hotkey)
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.primary)

            Spacer()
        }
    }
}

// MARK: - Plain Button Style (No Focus Ring)

private struct PlainNoFocusButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

// MARK: - Preview

#Preview {
    SettingsView(
        permissionManager: PermissionManager(),
        appState: AppState(),
        hotkeyManager: .constant(nil),
        historyManager: nil
    )
}
