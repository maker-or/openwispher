//
//  HomeView.swift
//  OpenWispher
//
//  Redesigned home UI matching the provided design specs.
//

import AppKit
internal import Combine
import SwiftData
import SwiftUI

struct HomeView: View {
    @Bindable var appState: AppState
    var permissionManager: PermissionManager
    var historyManager: HistoryManager?
    var ttsService: TextToSpeechService?

    @StateObject private var homeViewModel: HomeContentViewModel
    @SceneStorage("home.selectedSection") private var selectedSectionRaw: String = HomeSection.home
        .rawValue

    enum HomeSection: String, CaseIterable {
        case home = "Home"
        case settings = "Settings"
    }

    private var selectedSectionBinding: Binding<HomeSection> {
        Binding(
            get: { HomeSection(rawValue: selectedSectionRaw) ?? .home },
            set: { selectedSectionRaw = $0.rawValue }
        )
    }

    init(
        appState: AppState,
        permissionManager: PermissionManager,
        historyManager: HistoryManager?,
        ttsService: TextToSpeechService?
    ) {
        self.appState = appState
        self.permissionManager = permissionManager
        self.historyManager = historyManager
        self.ttsService = ttsService
        _homeViewModel = StateObject(
            wrappedValue: HomeContentViewModel(historyManager: historyManager))
    }

    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()

            NavigationSplitView {
                List(selection: selectedSectionBinding) {
                    Section {
                        SidebarRow(
                            title: "Home",
                            icon: "house",
                            isSelected: selectedSectionBinding.wrappedValue == .home
                        )
                        .tag(HomeSection.home)
                        SidebarRow(
                            title: "Settings",
                            icon: "gear",
                            isSelected: selectedSectionBinding.wrappedValue == .settings
                        )
                        .tag(HomeSection.settings)
                    } header: {
                        Text("Openwispher")
                            .font(.headline)
                            .textCase(nil)
                            .foregroundStyle(.primary)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .background(.ultraThinMaterial)

            } detail: {
                switch selectedSectionBinding.wrappedValue {
                case .home:
                    VStack(spacing: 0) {
                        HomeContentView(viewModel: homeViewModel)
                    }
                case .settings:
                    SettingsContentView(
                        permissionManager: permissionManager,
                        appState: appState,
                        historyManager: historyManager
                    )
                }
            }
        }
        .frame(minWidth: 600, minHeight: 450)
        // ensure stable “light” Control Center style glass
        .preferredColorScheme(.none)

    }
}

private struct SidebarRow: View {
    let title: String
    let icon: String
    let isSelected: Bool

    var body: some View {
        Label(title, systemImage: icon)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.clear))
            )
            .listRowBackground(Color.clear)
    }
}

// MARK: - Cached Noise Texture (Performance Optimized)
/// Noise texture that renders once and caches the result as an image
struct CachedNoiseTexture: View {
    @State private var noiseImage: NSImage?

    var body: some View {
        GeometryReader { geometry in
            if let image = noiseImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.clear
                    .onAppear {
                        generateNoiseImage(size: geometry.size)
                    }
            }
        }
    }

    private func generateNoiseImage(size: CGSize) {
        // Generate noise on background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            let width = Int(size.width)
            let height = Int(size.height)

            guard width > 0 && height > 0 else { return }

            let image = NSImage(size: size)
            image.lockFocus()

            // Draw fewer, larger noise particles for better performance
            let particleCount = min(5000, (width * height) / 50)

            NSColor.black.withAlphaComponent(0.05).setFill()

            for _ in 0..<particleCount {
                let x = CGFloat.random(in: 0..<CGFloat(width))
                let y = CGFloat.random(in: 0..<CGFloat(height))
                NSBezierPath(rect: CGRect(x: x, y: y, width: 1, height: 1)).fill()
            }

            image.unlockFocus()

            DispatchQueue.main.async {
                self.noiseImage = image
            }
        }
    }
}

// Legacy NoiseTexture kept for compatibility
struct NoiseTexture: View {
    var body: some View {
        CachedNoiseTexture()
    }
}

// MARK: - Home Content (Transcriptions) - Event-driven refresh
struct HomeContentView: View {
    @ObservedObject var viewModel: HomeContentViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var recentlyCopiedId: UUID?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if viewModel.transcriptions.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                            .frame(height: 100)
                        Text("No transcriptions yet")
                            .font(.system(size: 16))
                            .foregroundStyle(.black.opacity(0.4))
                    }
                } else {
                    ForEach(viewModel.transcriptions, id: \.id) { (record: TranscriptionRecord) in
                        VStack(alignment: .leading, spacing: 0) {
                            Text(record.text)
                                .font(.system(size: 14))
                                .foregroundStyle(.black.opacity(0.8))
                                .lineLimit(3)
                                .padding(.horizontal, 32)
                                .padding(.top, 16)
                                .padding(.bottom, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // Row actions (icon-only)
                            HStack(spacing: 14) {
                                Button {
                                    copy(record)
                                } label: {
                                    Image(
                                        systemName: recentlyCopiedId == record.id
                                            ? "checkmark" : "doc.on.doc"
                                    )
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.black.opacity(0.55))
                                }
                                .buttonStyle(.plain)
                                .handCursor()
                                .accessibilityLabel("Copy transcription")
                                .help("Copy")

                                Button {
                                    delete(record)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.black.opacity(0.55))
                                }
                                .buttonStyle(.plain)
                                .handCursor()
                                .accessibilityLabel("Delete transcription")
                                .help("Delete")

                                Spacer()
                            }
                            .padding(.horizontal, 32)
                            .padding(.bottom, 12)

                            Rectangle()
                                .fill(Color.black.opacity(0.1))
                                .frame(height: 1)
                                .padding(.horizontal, 32)
                        }
                    }
                }
            }
        }
        .onAppear {
            // Initial load
            viewModel.refreshIfNeeded()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: TranscriptionService.transcriptionSavedNotification)
        ) { _ in
            // Event-driven refresh when new transcription is saved
            viewModel.refreshIfNeeded(force: true)
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Refresh when becoming active
            if newPhase == .active {
                viewModel.refreshIfNeeded(force: true)
            }
        }
    }

    private func copy(_ record: TranscriptionRecord) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(record.text, forType: .string)

        recentlyCopiedId = record.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if recentlyCopiedId == record.id {
                recentlyCopiedId = nil
            }
        }
    }

    private func delete(_ record: TranscriptionRecord) {
        viewModel.delete(record)
    }
}

@MainActor
final class HomeContentViewModel: ObservableObject {
    @Published var transcriptions: [TranscriptionRecord] = []

    private var historyManager: HistoryManager?
    private var hasLoadedOnce = false

    init(historyManager: HistoryManager?) {
        self.historyManager = historyManager
    }

    func refreshIfNeeded(force: Bool = false) {
        if force || !hasLoadedOnce {
            logLoad("refresh start", count: transcriptions.count)
            load()
            hasLoadedOnce = true
        }
    }

    func delete(_ record: TranscriptionRecord) {
        historyManager?.deleteTranscription(record)
        load()
    }

    private func load() {
        guard let manager = historyManager else {
            transcriptions = []
            return
        }
        let newItems = manager.fetchAllTranscriptions()
        if shouldUpdateTranscriptions(newItems) {
            transcriptions = newItems
            logLoad("updated", count: newItems.count)
        } else {
            logLoad("skipped (no changes)", count: newItems.count)
        }
    }

    private func shouldUpdateTranscriptions(_ newItems: [TranscriptionRecord]) -> Bool {
        if newItems.count != transcriptions.count {
            return true
        }
        for (lhs, rhs) in zip(newItems, transcriptions) {
            if lhs.id != rhs.id || lhs.text != rhs.text || lhs.timestamp != rhs.timestamp
                || lhs.isFavorite != rhs.isFavorite
            {
                return true
            }
        }
        return false
    }

    private func logLoad(_ message: String, count: Int) {
        #if DEBUG
            print("🧭 [HomeContentViewModel] load \(message) (count: \(count))")
        #endif
    }
}

private struct HandCursorOnHover: ViewModifier {
    func body(content: Content) -> some View {
        content.onHover { isHovering in
            if isHovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}

extension View {
    fileprivate func handCursor() -> some View {
        modifier(HandCursorOnHover())
    }
}

// MARK: - Settings Content
struct SettingsContentView: View {
    var permissionManager: PermissionManager
    @Bindable var appState: AppState
    var historyManager: HistoryManager?

    @AppStorage("selectedTranscriptionProvider") private var selectedProviderRaw = "Groq"
    @AppStorage("selectedTTSProvider") private var selectedTTSProviderRaw = "Groq"
    @State private var groqAPIKey = ""
    @State private var elevenLabsAPIKey = ""
    @State private var deepgramAPIKey = ""
    @State private var openAIAPIKey = ""
    @State private var isEditingTranscriptionKey = false
    @State private var isEditingTTSKey = false
    @State private var hasTranscriptionKey = false
    @State private var hasTTSKey = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Section: Permissions
                SettingsSection(title: "Permissions") {
                    VStack(spacing: 0) {
                        // Microphone
                        HStack {
                            Text("Microphone")
                                .font(.system(size: 14))
                                .foregroundStyle(.black.opacity(0.8))
                            Spacer()
                            if permissionManager.hasMicrophonePermission {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Button("Request") {
                                    Task {
                                        await permissionManager.requestMicrophonePermission()
                                    }
                                }
                                .liquidGlassButtonStyle(prominent: true)
                                .controlSize(.small)
                            }
                        }
                        .padding()

                        Divider()
                            .background(Color.black.opacity(0.1))

                        // Accessibility
                        HStack {
                            Text("Accessibility")
                                .font(.system(size: 14))
                                .foregroundStyle(.black.opacity(0.8))
                            Spacer()
                            if permissionManager.hasAccessibilityPermission {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Button("Open Settings") {
                                    permissionManager.requestAccessibilityPermission()
                                }
                                .liquidGlassButtonStyle(prominent: true)
                                .controlSize(.small)
                            }
                        }
                        .padding()
                    }
                    .liquidGlassSurface(cornerRadius: 8)
                }

                // Section: Transcription Provider
                SettingsSection(title: "Transcription Provider") {
                    VStack(spacing: 0) {
                        ForEach(TranscriptionProviderType.allCases) { provider in
                            ProviderRow(
                                name: provider.displayName,
                                isSelected: selectedProviderRaw == provider.rawValue
                            ) {
                                selectedProviderRaw = provider.rawValue
                                isEditingTranscriptionKey = false
                                checkTranscriptionKeyStatus()
                            }

                            if provider != TranscriptionProviderType.allCases.last {
                                Divider()
                                    .background(Color.black.opacity(0.1))
                            }
                        }
                    }
                    .liquidGlassSurface(cornerRadius: 8)

                    // API Key Management (Hidden by default)
                    APIKeySection(
                        providerName: selectedProviderRaw,
                        isEditing: $isEditingTranscriptionKey,
                        hasKey: hasTranscriptionKey,
                        onAdd: { isEditingTranscriptionKey = true },
                        onUpdate: { isEditingTranscriptionKey = true },
                        onRemove: {
                            deleteTranscriptionKey()
                            hasTranscriptionKey = false
                        },
                        content: {
                            HStack(spacing: 8) {
                                SecureField("Enter API Key", text: transcriptionKeyBinding)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .liquidGlassSurface(cornerRadius: 8, interactive: true)
                                
                                Button("Cancel") {
                                    isEditingTranscriptionKey = false
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                
                                Button("Save") {
                                    isEditingTranscriptionKey = false
                                    hasTranscriptionKey = !transcriptionKeyBinding.wrappedValue.isEmpty
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(transcriptionKeyBinding.wrappedValue.isEmpty)
                            }
                        }
                    )
                    .padding(.top, 10)
                }

                // Section: Text-to-Speech Provider
                SettingsSection(title: "Text-to-Speech Provider") {
                    VStack(spacing: 0) {
                        ForEach(TTSProviderType.allCases) { provider in
                            ProviderRow(
                                name: provider.displayName,
                                isSelected: selectedTTSProviderRaw == provider.rawValue
                            ) {
                                selectedTTSProviderRaw = provider.rawValue
                                isEditingTTSKey = false
                                checkTTSKeyStatus()
                            }

                            if provider != TTSProviderType.allCases.last {
                                Divider()
                                    .background(Color.black.opacity(0.1))
                            }
                        }
                    }
                    .liquidGlassSurface(cornerRadius: 8)

                    // API Key Management (Hidden by default)
                    APIKeySection(
                        providerName: selectedTTSProviderRaw,
                        isEditing: $isEditingTTSKey,
                        hasKey: hasTTSKey,
                        onAdd: { isEditingTTSKey = true },
                        onUpdate: { isEditingTTSKey = true },
                        onRemove: {
                            deleteTTSKey()
                            hasTTSKey = false
                        },
                        content: {
                            HStack(spacing: 8) {
                                SecureField("Enter API Key", text: ttsKeyBinding)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .liquidGlassSurface(cornerRadius: 8, interactive: true)
                                
                                Button("Cancel") {
                                    isEditingTTSKey = false
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                
                                Button("Save") {
                                    isEditingTTSKey = false
                                    hasTTSKey = !ttsKeyBinding.wrappedValue.isEmpty
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(ttsKeyBinding.wrappedValue.isEmpty)
                            }
                        }
                    )
                    .padding(.top, 10)
                }

                // Section: General
                SettingsSection(title: "General") {
                    VStack(spacing: 0) {
                        ToggleRow(
                            title: "Launch at Login",
                            isOn: Binding(
                                get: { UserDefaults.standard.bool(forKey: "autoLaunchEnabled") },
                                set: { UserDefaults.standard.set($0, forKey: "autoLaunchEnabled") }
                            ))
                    }
                    .liquidGlassSurface(cornerRadius: 8)
                }

                // Section: Data
                SettingsSection(title: "Data") {
                    Button {
                        historyManager?.deleteAllTranscriptions()
                    } label: {
                        HStack {
                            Text("Clear All History")
                                .font(.system(size: 14))
                                .foregroundStyle(.red.opacity(0.8))
                            Spacer()
                        }
                        .padding()
                        .liquidGlassSurface(cornerRadius: 8, tint: .red.opacity(0.1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            checkTranscriptionKeyStatus()
            checkTTSKeyStatus()
        }
    }

    private var selectedProvider: TranscriptionProviderType {
        TranscriptionProviderType(rawValue: selectedProviderRaw) ?? .groq
    }

    private var transcriptionKeyBinding: Binding<String> {
        switch selectedProvider {
        case .groq:
            return Binding(
                get: { groqAPIKey },
                set: {
                    groqAPIKey = $0
                    if $0.isEmpty {
                        try? SecureStorage.deleteAPIKey(for: .groq)
                    } else {
                        try? SecureStorage.storeAPIKey($0, for: .groq)
                    }
                }
            )
        case .elevenLabs:
            return Binding(
                get: { elevenLabsAPIKey },
                set: {
                    elevenLabsAPIKey = $0
                    if $0.isEmpty {
                        try? SecureStorage.deleteAPIKey(for: .elevenLabs)
                    } else {
                        try? SecureStorage.storeAPIKey($0, for: .elevenLabs)
                    }
                }
            )
        case .deepgram:
            return Binding(
                get: { deepgramAPIKey },
                set: {
                    deepgramAPIKey = $0
                    if $0.isEmpty {
                        try? SecureStorage.deleteAPIKey(for: .deepgram)
                    } else {
                        try? SecureStorage.storeAPIKey($0, for: .deepgram)
                    }
                }
            )
        }
    }

    private var selectedTTSProvider: TTSProviderType {
        TTSProviderType(rawValue: selectedTTSProviderRaw) ?? .groq
    }

    private var ttsKeyBinding: Binding<String> {
        switch selectedTTSProvider {
        case .groq:
            return Binding(
                get: { groqAPIKey },
                set: {
                    groqAPIKey = $0
                    if $0.isEmpty {
                        try? SecureStorage.deleteAPIKey(for: .groq)
                    } else {
                        try? SecureStorage.storeAPIKey($0, for: .groq)
                    }
                }
            )
        case .elevenLabs:
            return Binding(
                get: { elevenLabsAPIKey },
                set: {
                    elevenLabsAPIKey = $0
                    if $0.isEmpty {
                        try? SecureStorage.deleteAPIKey(for: .elevenLabs)
                    } else {
                        try? SecureStorage.storeAPIKey($0, for: .elevenLabs)
                    }
                }
            )
        case .deepgram:
            return Binding(
                get: { deepgramAPIKey },
                set: {
                    deepgramAPIKey = $0
                    if $0.isEmpty {
                        try? SecureStorage.deleteAPIKey(for: .deepgram)
                    } else {
                        try? SecureStorage.storeAPIKey($0, for: .deepgram)
                    }
                }
            )
        case .openAI:
            return Binding(
                get: { openAIAPIKey },
                set: {
                    openAIAPIKey = $0
                    if $0.isEmpty {
                        try? SecureStorage.deleteTTSAPIKey(for: .openAI)
                    } else {
                        try? SecureStorage.storeTTSAPIKey($0, for: .openAI)
                    }
                }
            )
        }
    }

    private func checkTranscriptionKeyStatus() {
        let key = SecureStorage.retrieveAPIKey(for: selectedProvider)
        hasTranscriptionKey = key != nil && !key!.isEmpty
    }

    private func checkTTSKeyStatus() {
        let key: String?
        switch selectedTTSProvider {
        case .openAI:
            key = SecureStorage.retrieveTTSAPIKey(for: .openAI)
        default:
            key = SecureStorage.retrieveAPIKey(for: TranscriptionProviderType(rawValue: selectedTTSProviderRaw) ?? .groq)
        }
        hasTTSKey = key != nil && !key!.isEmpty
    }

    private func deleteTranscriptionKey() {
        try? SecureStorage.deleteAPIKey(for: selectedProvider)
    }

    private func deleteTTSKey() {
        switch selectedTTSProvider {
        case .openAI:
            try? SecureStorage.deleteTTSAPIKey(for: .openAI)
        default:
            if let provider = TranscriptionProviderType(rawValue: selectedTTSProviderRaw) {
                try? SecureStorage.deleteAPIKey(for: provider)
            }
        }
    }
}

// MARK: - Settings Section
private struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.black.opacity(0.5))
                .textCase(.uppercase)

            content
        }
    }
}

// MARK: - Provider Row
private struct ProviderRow: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(name)
                    .font(.system(size: 14))
                    .foregroundStyle(.black.opacity(0.8))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.8))
                }
            }
            .padding()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - API Key Section
private struct APIKeySection<Content: View>: View {
    let providerName: String
    @Binding var isEditing: Bool
    let hasKey: Bool
    let onAdd: () -> Void
    let onUpdate: () -> Void
    let onRemove: () -> Void
    let content: Content

    init(
        providerName: String,
        isEditing: Binding<Bool>,
        hasKey: Bool,
        onAdd: @escaping () -> Void,
        onUpdate: @escaping () -> Void,
        onRemove: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.providerName = providerName
        self._isEditing = isEditing
        self.hasKey = hasKey
        self.onAdd = onAdd
        self.onUpdate = onUpdate
        self.onRemove = onRemove
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(providerName) API Key")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.black.opacity(0.5))

            if isEditing {
                content
            } else {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: hasKey ? "checkmark.seal.fill" : "key.slash")
                            .font(.system(size: 12))
                            .foregroundStyle(hasKey ? .green : .secondary)

                        Text(hasKey ? "API key configured" : "No API key")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if hasKey {
                        Menu {
                            Button("Update Key", action: onUpdate)
                            Button("Remove Key", role: .destructive, action: onRemove)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button("Add API Key", action: onAdd)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
        }
    }
}

// MARK: - Toggle Row
private struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(.black.opacity(0.8))
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding()
    }
}
