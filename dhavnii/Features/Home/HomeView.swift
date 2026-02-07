//
//  HomeView.swift
//  OpenWispher
//
//  Native macOS home view with liquid glass styling.
//

import AppKit
import SwiftData
import SwiftUI

struct HomeView: View {
    @Bindable var appState: AppState
    var permissionManager: PermissionManager
    var historyManager: HistoryManager?

    @State private var homeViewModel: HomeContentViewModel
    @State private var selectedSection: SidebarSection = .transcriptions
    @State private var hoveredSection: SidebarSection?

    @Environment(\.openWindow) private var openWindow

    private enum SidebarSection: String, CaseIterable, Identifiable {
        case transcriptions = "Transcriptions"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .transcriptions: return "waveform"
            }
        }

        var iconGradient: [Color] {
            switch self {
            case .transcriptions:
                return [
                    Color(red: 0.24, green: 0.70, blue: 0.98),
                    Color(red: 0.10, green: 0.48, blue: 0.92),
                ]
            }
        }
    }

    init(
        appState: AppState,
        permissionManager: PermissionManager,
        historyManager: HistoryManager?
    ) {
        self.appState = appState
        self.permissionManager = permissionManager
        self.historyManager = historyManager
        _homeViewModel = State(
            wrappedValue: HomeContentViewModel(historyManager: historyManager))
    }

    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        .frame(minWidth: 700, minHeight: 500)
        .preferredColorScheme(.dark)
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // App Header
            VStack(spacing: 8) {
                Text("OpenWispher")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Navigation Items
            List(selection: $selectedSection) {
                Section {
                    ForEach(SidebarSection.allCases) { section in
                        sidebarItem(for: section)
                            .tag(section)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .tint(nil)  // THIS LINE DISABLES SYSTEM BLUE HIGHLIGHT

            .safeAreaInset(edge: .bottom) {
                // Bottom Actions
                VStack(spacing: 12) {
                    Button {
                        openWindow(id: "settings")
                    } label: {
                        HStack(spacing: 10) {
                            SidebarIconTile(
                                systemName: "gearshape",
                                colors: [
                                    Color(red: 0.64, green: 0.72, blue: 0.98),
                                    Color(red: 0.42, green: 0.50, blue: 0.90),

                                ],
                                size: 24,
                                symbolSize: 12
                            )

                            Text("Settings")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary)

                            Spacer()

                            Text("⌘,")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary.opacity(0.6))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(",", modifiers: .command)
                    .help("Open Settings")
                    .accessibilityLabel("Open Settings")
                    .padding(.horizontal, 12)
                }
                .padding(.bottom, 12)
            }
        }
        .frame(minWidth: 220)
        .background(.ultraThinMaterial)
    }

    private func sidebarItem(for section: SidebarSection) -> some View {
        let isSelected = selectedSection == section

        return HStack(spacing: 10) {

            Text(section.rawValue)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? Color.white : Color.primary)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 10, style: .continuous)

                .padding(.horizontal, 6)
        )
    }

    private var statusIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            Spacer()
        }
        .accessibilityElement(children: .combine)

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

    // MARK: - Detail Content

    private var detailContent: some View {
        HomeContentView(viewModel: homeViewModel, appState: appState)
            .background(.ultraThinMaterial.opacity(0.3))
    }
}

// MARK: - Home Content View (Transcriptions List)

struct HomeContentView: View {
    var viewModel: HomeContentViewModel
    var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @State private var recentlyCopiedId: UUID?
    @State private var hoveredId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            contentHeader

            Divider()

            // Content
            if viewModel.transcriptions.isEmpty {
                emptyStateView
            } else {
                transcriptionsList
            }
        }
        .onAppear {
            viewModel.refreshIfNeeded()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: TranscriptionService.transcriptionSavedNotification)
        ) { _ in
            viewModel.refreshIfNeeded(force: true)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.refreshIfNeeded(force: true)
            }
        }
    }

    // MARK: - Header

    private var contentHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Home")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial.opacity(0.5))
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)

                Image(systemName: "waveform.badge.mic")
                    .font(.system(size: 40, weight: .thin))
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 8) {
                Text("No Transcriptions Yet")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text("Press ⌥ Space to start recording")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Your transcriptions will appear here")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No transcriptions. Press Option Space to start recording.")
    }

    // MARK: - Transcriptions List

    private var transcriptionsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.transcriptions, id: \.id) { record in
                    TranscriptionRow(
                        record: record,
                        isCopied: recentlyCopiedId == record.id,
                        isHovered: hoveredId == record.id,
                        onCopy: { copy(record) },
                        onDelete: { delete(record) }
                    )
                    .onHover { isHovered in
                        hoveredId = isHovered ? record.id : nil
                    }

                    if record.id != viewModel.transcriptions.last?.id {
                        Divider()
                            .padding(.horizontal, 24)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Actions

    private func copy(_ record: TranscriptionRecord) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(record.text, forType: .string)

        recentlyCopiedId = record.id

        // Play feedback sound
        NSSound(named: "Pop")?.play()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if recentlyCopiedId == record.id {
                recentlyCopiedId = nil
            }
        }
    }

    private func delete(_ record: TranscriptionRecord) {
        viewModel.delete(record)
    }
}

// MARK: - Transcription Row

private struct TranscriptionRow: View {
    let record: TranscriptionRecord
    let isCopied: Bool
    let isHovered: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Text Content
            Text(record.text)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .accessibilityLabel("Transcription: \(record.text)")

            // Actions
            HStack(spacing: 16) {
                Button {
                    onCopy()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12, weight: .medium))
                        Text(isCopied ? "Copied" : "Copy")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(isCopied ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .contentTransition(.symbolEffect(.replace))
                .help("Copy to clipboard")
                .accessibilityLabel(isCopied ? "Copied" : "Copy transcription")

                Button {
                    onDelete()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .medium))
                        Text("Delete")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete transcription")
                .accessibilityLabel("Delete transcription")

                Spacer()
            }
            .opacity(isHovered ? 1 : 0.6)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(isHovered ? 0.05 : 0))
        )
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .contentShape(Rectangle())
    }
}

// MARK: - View Model

@MainActor
@Observable
final class HomeContentViewModel {
    var transcriptions: [TranscriptionRecord] = []

    private var historyManager: HistoryManager?
    private var hasLoadedOnce = false

    init(historyManager: HistoryManager?) {
        self.historyManager = historyManager
    }

    func refreshIfNeeded(force: Bool = false) {
        if force || !hasLoadedOnce {
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
}

// MARK: - Preview

#Preview {
    HomeView(
        appState: AppState(),
        permissionManager: PermissionManager(),
        historyManager: nil
    )
}
