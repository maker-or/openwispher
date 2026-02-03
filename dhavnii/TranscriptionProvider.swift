//
//  TranscriptionProvider.swift
//  OpenWispher
//
//  Protocol and types for multiple transcription providers.
//

import Foundation

/// Supported transcription providers
enum TranscriptionProviderType: String, CaseIterable, Identifiable {
    case groq = "Groq"
    case elevenLabs = "ElevenLabs"
    case deepgram = "Deepgram"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .groq: return "Groq (Whisper)"
        case .elevenLabs: return "ElevenLabs"
        case .deepgram: return "Deepgram"
        }
    }
    
    var description: String {
        switch self {
        case .groq:
            return "Fast Whisper-based transcription with competitive pricing"
        case .elevenLabs:
            return "High-quality speech-to-text with advanced features"
        case .deepgram:
            return "Enterprise-grade transcription with real-time capabilities"
        }
    }
}

/// Protocol that all transcription providers must implement
protocol TranscriptionProvider {
    /// Unique identifier for this provider
    var providerType: TranscriptionProviderType { get }
    
    /// Transcribe audio data to text
    /// - Parameters:
    ///   - audioData: The audio data to transcribe
    ///   - fileName: Optional filename for the audio (used in multipart forms)
    /// - Returns: The transcribed text
    /// - Throws: TranscriptionError if transcription fails
    func transcribe(audioData: Data, fileName: String) async throws -> String
    
    /// Check if the provider is properly configured (has valid API key, etc.)
    var isConfigured: Bool { get }
}

/// Unified error type for all transcription providers
enum TranscriptionError: Error, LocalizedError {
    case missingAPIKey(provider: String)
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case emptyTranscription
    case networkError(Error)
    case decodingError(Error)
    case providerNotConfigured
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "\(provider) API key not configured"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        case .emptyTranscription:
            return "Transcription returned empty text"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .providerNotConfigured:
            return "Transcription provider not properly configured"
        }
    }
}
