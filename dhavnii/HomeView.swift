//
//  HomeView.swift
//  OpenWispher
//
//  Redesigned home UI matching the provided design specs.
//

import AppKit
import SwiftUI
import SwiftData

struct HomeView: View {
    @Bindable var appState: AppState
    var permissionManager: PermissionManager
    var historyManager: HistoryManager?
    var ttsService: TextToSpeechService?
    
    @State private var selectedTab: HomeTab = .home
    
    enum HomeTab: String, CaseIterable {
        case home = "Home"
        case settings = "Settings"
    }
    
    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()
            
            // Cached Noise Texture Overlay (optimized - renders once)

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Openwispher")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)
                .padding(.bottom, 24)
                
                TabView(selection: $selectedTab) {
                    HomeContentView(historyManager: historyManager)
                        .tabItem {
                            Label("Home", systemImage: "house")
                        }
                        .tag(HomeTab.home)

                    SettingsContentView(
                        permissionManager: permissionManager,
                        appState: appState,
                        historyManager: historyManager
                    )
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(HomeTab.settings)
                }
                .tabViewStyle(.automatic)
            }
        }
        .frame(minWidth: 600, minHeight: 450)
        // ensure stable “light” Control Center style glass
        .preferredColorScheme(.light)
        .withToasts()
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
    var historyManager: HistoryManager?
    @State private var transcriptions: [TranscriptionRecord] = []
    @Environment(\.scenePhase) private var scenePhase
    @State private var recentlyCopiedId: UUID?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if transcriptions.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                            .frame(height: 100)
                        Text("No transcriptions yet")
                            .font(.system(size: 16))
                            .foregroundStyle(.black.opacity(0.4))
                    }
                } else {
                    ForEach(transcriptions, id: \.id) { (record: TranscriptionRecord) in
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
                                    Image(systemName: recentlyCopiedId == record.id ? "checkmark" : "doc.on.doc")
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
            refreshTranscriptions()
        }
        .onReceive(NotificationCenter.default.publisher(for: TranscriptionService.transcriptionSavedNotification)) { _ in
            // Event-driven refresh when new transcription is saved
            refreshTranscriptions()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Refresh when becoming active
            if newPhase == .active {
                refreshTranscriptions()
            }
        }
    }
    
    private func refreshTranscriptions() {
        if let manager = historyManager {
            transcriptions = manager.fetchAllTranscriptions()
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
        historyManager?.deleteTranscription(record)
        refreshTranscriptions()
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

private extension View {
    func handCursor() -> some View {
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
    @State private var showAPIKey = false
    @State private var showTTSAPIKey = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Section: Permissions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Permissions")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.5))
                        .textCase(.uppercase)
                    
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
                
                // Section: Provider
                VStack(alignment: .leading, spacing: 12) {
                    Text("Transcription Provider")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.5))
                        .textCase(.uppercase)
                    
                    VStack(spacing: 0) {
                        ForEach(TranscriptionProviderType.allCases) { provider in
                            Button {
                                selectedProviderRaw = provider.rawValue
                                showAPIKey = false
                            } label: {
                                HStack {
                                    Text(provider.displayName)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.black.opacity(0.8))
                                    Spacer()
                                    if selectedProviderRaw == provider.rawValue {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.black.opacity(0.8))
                                    }
                                }
                                .padding()
                            }
                            .buttonStyle(.plain)
                            
                            if provider != TranscriptionProviderType.allCases.last {
                                Divider()
                                    .background(Color.black.opacity(0.1))
                            }
                        }
                    }
                    .liquidGlassSurface(cornerRadius: 8)

                    // API Key (shown for selected provider)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(selectedProviderRaw) API Key")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.5))

                        HStack(spacing: 8) {
                            Group {
                                if showAPIKey {
                                    TextField("Enter API Key", text: selectedAPIKeyBinding)
                                } else {
                                    SecureField("Enter API Key", text: selectedAPIKeyBinding)
                                }
                            }
                            .textFieldStyle(.plain)
                            .padding(10)
                            .liquidGlassSurface(cornerRadius: 8, interactive: true)

                            Button {
                                showAPIKey.toggle()
                                if showAPIKey {
                                    loadAPIKeysFromKeychain()
                                }
                            } label: {
                                Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.black.opacity(0.55))
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)
                            .handCursor()
                            .help(showAPIKey ? "Hide API key" : "Show API key")
                            .accessibilityLabel(showAPIKey ? "Hide API key" : "Show API key")
                        }
                    }
                    .padding(.top, 10)
                }
                
                // Section: Text-to-Speech Provider
                VStack(alignment: .leading, spacing: 12) {
                    Text("Text-to-Speech Provider")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.5))
                        .textCase(.uppercase)

                    VStack(spacing: 0) {
                        ForEach(TTSProviderType.allCases) { provider in
                            Button {
                                selectedTTSProviderRaw = provider.rawValue
                                showTTSAPIKey = false
                            } label: {
                                HStack {
                                    Text(provider.displayName)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.black.opacity(0.8))
                                    Spacer()
                                    if selectedTTSProviderRaw == provider.rawValue {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.black.opacity(0.8))
                                    }
                                }
                                .padding()
                            }
                            .buttonStyle(.plain)

                            if provider != TTSProviderType.allCases.last {
                                Divider()
                                    .background(Color.black.opacity(0.1))
                            }
                        }
                    }
                    .liquidGlassSurface(cornerRadius: 8)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(selectedTTSProviderRaw) API Key")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.5))

                        HStack(spacing: 8) {
                            Group {
                                if showTTSAPIKey {
                                    TextField("Enter API Key", text: selectedTTSAPIKeyBinding)
                                } else {
                                    SecureField("Enter API Key", text: selectedTTSAPIKeyBinding)
                                }
                            }
                            .textFieldStyle(.plain)
                            .padding(10)
                            .liquidGlassSurface(cornerRadius: 8, interactive: true)

                            Button {
                                showTTSAPIKey.toggle()
                                if showTTSAPIKey {
                                    loadAPIKeysFromKeychain()
                                }
                            } label: {
                                Image(systemName: showTTSAPIKey ? "eye.slash" : "eye")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.black.opacity(0.55))
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)
                            .handCursor()
                            .help(showTTSAPIKey ? "Hide API key" : "Show API key")
                            .accessibilityLabel(showTTSAPIKey ? "Hide API key" : "Show API key")
                        }
                    }
                    .padding(.top, 10)
                }

                // Section: General
                VStack(alignment: .leading, spacing: 12) {
                    Text("General")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.5))
                        .textCase(.uppercase)
                    
                    VStack(spacing: 0) {
                        ToggleRow(title: "Launch at Login", isOn: Binding(
                            get: { UserDefaults.standard.bool(forKey: "autoLaunchEnabled") },
                            set: { UserDefaults.standard.set($0, forKey: "autoLaunchEnabled") }
                        ))
                    }
                    .liquidGlassSurface(cornerRadius: 8)
                }
                
                // Section: Data
                VStack(alignment: .leading, spacing: 12) {
                    Text("Data")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.5))
                        .textCase(.uppercase)
                    
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
            // Defer keychain reads until the user explicitly reveals keys.
        }
    }

    private var selectedProvider: TranscriptionProviderType {
        TranscriptionProviderType(rawValue: selectedProviderRaw) ?? .groq
    }

    private var selectedAPIKeyBinding: Binding<String> {
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

    private var selectedTTSAPIKeyBinding: Binding<String> {
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
    
    private func loadAPIKeysFromKeychain() {
        groqAPIKey = SecureStorage.retrieveAPIKey(for: .groq) ?? ""
        elevenLabsAPIKey = SecureStorage.retrieveAPIKey(for: .elevenLabs) ?? ""
        deepgramAPIKey = SecureStorage.retrieveAPIKey(for: .deepgram) ?? ""
        openAIAPIKey = SecureStorage.retrieveTTSAPIKey(for: .openAI) ?? ""
    }
}

struct ToggleRow: View {
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
        .liquidGlassSurface(cornerRadius: 8, interactive: true)
    }
}
