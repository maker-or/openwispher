//
//  HistoryManager.swift
//  OpenWispher
//
//  Manages transcription history with automatic cleanup.
//

import Foundation
import SwiftData

/// Manages transcription history storage and cleanup
@MainActor
@Observable
class HistoryManager {
    private let modelContext: ModelContext
    
    /// Default retention period in days
    private let defaultRetentionDays = 30
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // Perform cleanup on initialization
        cleanupOldTranscriptions()
    }
    
    /// Save a new transcription to history
    func saveTranscription(text: String, provider: TranscriptionProviderType, audioDuration: Double? = nil) {
        let record = TranscriptionRecord(
            text: text,
            provider: provider.rawValue,
            audioDuration: audioDuration
        )
        
        modelContext.insert(record)
        
        do {
            try modelContext.save()
            print("✅ Saved transcription to history")
        } catch {
            print("❌ Failed to save transcription: \(error)")
        }
        
        // Trigger cleanup after adding new record
        cleanupOldTranscriptions()
    }
    
    /// Fetch all transcriptions sorted by date (newest first)
    func fetchAllTranscriptions() -> [TranscriptionRecord] {
        let descriptor = FetchDescriptor<TranscriptionRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ Failed to fetch transcriptions: \(error)")
            return []
        }
    }
    
    /// Fetch transcriptions with search query
    func searchTranscriptions(query: String) -> [TranscriptionRecord] {
        let descriptor = FetchDescriptor<TranscriptionRecord>(
            predicate: #Predicate { record in
                record.text.localizedStandardContains(query)
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ Failed to search transcriptions: \(error)")
            return []
        }
    }
    
    /// Delete a specific transcription
    func deleteTranscription(_ record: TranscriptionRecord) {
        modelContext.delete(record)
        
        do {
            try modelContext.save()
            print("✅ Deleted transcription")
        } catch {
            print("❌ Failed to delete transcription: \(error)")
        }
    }
    
    /// Delete all transcriptions
    func deleteAllTranscriptions() {
        let descriptor = FetchDescriptor<TranscriptionRecord>()
        
        do {
            let allRecords = try modelContext.fetch(descriptor)
            for record in allRecords {
                modelContext.delete(record)
            }
            try modelContext.save()
            print("✅ Deleted all transcriptions")
        } catch {
            print("❌ Failed to delete all transcriptions: \(error)")
        }
    }
    
    /// Toggle favorite status
    func toggleFavorite(_ record: TranscriptionRecord) {
        record.isFavorite.toggle()
        
        do {
            try modelContext.save()
            print("✅ Updated favorite status")
        } catch {
            print("❌ Failed to update favorite status: \(error)")
        }
    }
    
    /// Cleanup old transcriptions based on retention policy
    private func cleanupOldTranscriptions() {
        let preferences = getOrCreatePreferences()
        let retentionDays = preferences.retentionDays
        
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -retentionDays,
            to: Date()
        )!
        
        // Delete records older than retention period that are not favorites
        let descriptor = FetchDescriptor<TranscriptionRecord>(
            predicate: #Predicate { record in
                record.timestamp < cutoffDate && !record.isFavorite
            }
        )
        
        do {
            let oldRecords = try modelContext.fetch(descriptor)
            for record in oldRecords {
                modelContext.delete(record)
            }
            
            if !oldRecords.isEmpty {
                try modelContext.save()
                print("🧹 Cleaned up \(oldRecords.count) old transcriptions")
            }
            
            // Update last cleanup date
            preferences.lastCleanupDate = Date()
            try modelContext.save()
        } catch {
            print("❌ Failed to cleanup old transcriptions: \(error)")
        }
    }
    
    /// Get or create history preferences
    private func getOrCreatePreferences() -> HistoryPreferences {
        let descriptor = FetchDescriptor<HistoryPreferences>()
        
        do {
            if let existing = try modelContext.fetch(descriptor).first {
                return existing
            }
        } catch {
            print("❌ Failed to fetch preferences: \(error)")
        }
        
        // Create default preferences
        let preferences = HistoryPreferences(retentionDays: defaultRetentionDays)
        modelContext.insert(preferences)
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to save preferences: \(error)")
        }
        
        return preferences
    }
    
    /// Update retention settings
    func updateRetentionDays(_ days: Int) {
        let preferences = getOrCreatePreferences()
        preferences.retentionDays = days
        
        do {
            try modelContext.save()
            print("✅ Updated retention to \(days) days")
            cleanupOldTranscriptions()
        } catch {
            print("❌ Failed to update retention settings: \(error)")
        }
    }
    
    /// Get total count of transcriptions
    func getTranscriptionCount() -> Int {
        let descriptor = FetchDescriptor<TranscriptionRecord>()
        
        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            print("❌ Failed to get count: \(error)")
            return 0
        }
    }
}
