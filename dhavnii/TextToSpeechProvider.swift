//
//  TextToSpeechProvider.swift
//  OpenWispher
//
//  Protocols and types for text-to-speech providers.
//

import Foundation

/// Supported TTS providers
internal enum TTSProviderType: String, CaseIterable, Identifiable {
    case groq = "Groq"
    case deepgram = "Deepgram"
    case elevenLabs = "ElevenLabs"
    case openAI = "OpenAI"

    internal var id: String { rawValue }

    internal var displayName: String {
        switch self {
        case .groq: return "Groq"
        case .deepgram: return "Deepgram"
        case .elevenLabs: return "ElevenLabs"
        case .openAI: return "OpenAI"
        }
    }
}

/// Protocol for all TTS providers
internal protocol TextToSpeechProvider {
    var providerType: TTSProviderType { get }
    var isConfigured: Bool { get }
    func synthesize(text: String) async throws -> Data
}

/// Unified error type for all TTS providers
internal enum TTSError: Error, LocalizedError {
    case missingAPIKey(provider: String)
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case emptyAudio
    case networkError(Error)
    case decodingError(Error)
    case invalidText

    internal var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "\(provider) API key not configured"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        case .emptyAudio:
            return "Audio response was empty"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .invalidText:
            return "Text is empty or invalid"
        }
    }
}
