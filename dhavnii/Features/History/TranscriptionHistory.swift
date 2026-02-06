//
//  TranscriptionHistory.swift
//  OpenWispher
//
//  SwiftData models for local transcription history storage.
//

import Foundation
import SwiftData

/// Model for storing transcription history locally
@Model
class TranscriptionRecord {
    @Attribute(.unique) var id: UUID
    var text: String
    var timestamp: Date
    var provider: String
    var audioDuration: Double?
    var isFavorite: Bool
    
    init(
        id: UUID = UUID(),
        text: String,
        timestamp: Date = Date(),
        provider: String,
        audioDuration: Double? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.provider = provider
        self.audioDuration = audioDuration
        self.isFavorite = isFavorite
    }
}

/// User preferences for history management
@Model
class HistoryPreferences {
    var retentionDays: Int
    var maxTranscriptions: Int?
    var lastCleanupDate: Date
    
    init(
        retentionDays: Int = 30,
        maxTranscriptions: Int? = nil,
        lastCleanupDate: Date = Date()
    ) {
        self.retentionDays = retentionDays
        self.maxTranscriptions = maxTranscriptions
        self.lastCleanupDate = lastCleanupDate
    }
}
