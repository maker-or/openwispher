//
//  HistoryView.swift
//  OpenWispher
//
//  View for browsing and managing transcription history.
//

import SwiftUI
import SwiftData

/// View for displaying transcription history
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var historyManager: HistoryManager?
    @State private var transcriptions: [TranscriptionRecord] = []
    @State private var searchText = ""
    @State private var showingDeleteAllAlert = false
    @State private var selectedRecord: TranscriptionRecord?
    @State private var showingDetail = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $searchText)
                    .padding()
                
                // History list
                List {
                    ForEach(filteredTranscriptions) { record in
                        TranscriptionRow(record: record)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedRecord = record
                                showingDetail = true
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteRecord(record)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button {
                                    toggleFavorite(record)
                                } label: {
                                    Label(record.isFavorite ? "Unfavorite" : "Favorite",
                                          systemImage: record.isFavorite ? "star.slash" : "star")
                                }
                                .tint(.yellow)
                            }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(role: .destructive) {
                            showingDeleteAllAlert = true
                        } label: {
                            Label("Delete All", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Delete All Transcriptions?", isPresented: $showingDeleteAllAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete All", role: .destructive) {
                    deleteAllRecords()
                }
            } message: {
                Text("This will permanently delete all transcription history. This action cannot be undone.")
            }
            .sheet(isPresented: $showingDetail) {
                if let record = selectedRecord {
                    TranscriptionDetailView(record: record)
                }
            }
            .onAppear {
                loadHistoryManager()
            }
            .onChange(of: searchText) { _, _ in
                refreshTranscriptions()
            }
        }
    }
    
    private var filteredTranscriptions: [TranscriptionRecord] {
        if searchText.isEmpty {
            return transcriptions
        }
        return historyManager?.searchTranscriptions(query: searchText) ?? []
    }
    
    private func loadHistoryManager() {
        historyManager = HistoryManager(modelContext: modelContext)
        refreshTranscriptions()
    }
    
    private func refreshTranscriptions() {
        guard let manager = historyManager else { return }
        
        if searchText.isEmpty {
            transcriptions = manager.fetchAllTranscriptions()
        } else {
            transcriptions = manager.searchTranscriptions(query: searchText)
        }
    }
    
    private func deleteRecord(_ record: TranscriptionRecord) {
        historyManager?.deleteTranscription(record)
        refreshTranscriptions()
    }
    
    private func deleteAllRecords() {
        historyManager?.deleteAllTranscriptions()
        refreshTranscriptions()
    }
    
    private func toggleFavorite(_ record: TranscriptionRecord) {
        historyManager?.toggleFavorite(record)
        refreshTranscriptions()
    }
}

/// Search bar component
private struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search transcriptions...", text: $text)
                .textFieldStyle(.plain)
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .liquidGlassSurface(
            cornerRadius: 8,
            interactive: true,
            fallbackFill: Color(nsColor: .controlBackgroundColor)
        )
    }
}

/// Row component for transcription list
private struct TranscriptionRow: View {
    let record: TranscriptionRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Provider icon
                Image(systemName: providerIcon)
                    .foregroundColor(providerColor)
                    .font(.caption)
                
                // Timestamp
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Favorite indicator
                if record.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
            }
            
            // Preview text
            Text(previewText)
                .font(.body)
                .lineLimit(2)
                .truncationMode(.tail)
        }
        .padding(.vertical, 4)
    }
    
    private var previewText: String {
        record.text.isEmpty ? "(Empty transcription)" : record.text
    }
    
    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: record.timestamp, relativeTo: Date())
    }
    
    private var providerIcon: String {
        switch record.provider {
        case "Groq":
            return "bolt.fill"
        case "ElevenLabs":
            return "speaker.wave.2.fill"
        case "Deepgram":
            return "waveform"
        default:
            return "mic.fill"
        }
    }
    
    private var providerColor: Color {
        switch record.provider {
        case "Groq":
            return .orange
        case "ElevenLabs":
            return .blue
        case "Deepgram":
            return .purple
        default:
            return .secondary
        }
    }
}

/// Detail view for a transcription record
private struct TranscriptionDetailView: View {
    let record: TranscriptionRecord
    @Environment(\.dismiss) private var dismiss
    @State private var showingCopiedToast = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Metadata
                    HStack {
                        Label(formattedFullDate, systemImage: "calendar")
                        Spacer()
                        Label(record.provider, systemImage: providerIcon)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Divider()
                    
                    // Full text
                    Text(record.text)
                        .font(.body)
                        .textSelection(.enabled)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Transcription")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        copyToClipboard()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(record.text, forType: .string)
        showingCopiedToast = true
    }
    
    private var formattedFullDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: record.timestamp)
    }
    
    private var providerIcon: String {
        switch record.provider {
        case "Groq":
            return "bolt.fill"
        case "ElevenLabs":
            return "speaker.wave.2.fill"
        case "Deepgram":
            return "waveform"
        default:
            return "mic.fill"
        }
    }
}

#Preview {
    HistoryView()
}
