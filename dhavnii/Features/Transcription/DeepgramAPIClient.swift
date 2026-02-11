//
//  DeepgramAPIClient.swift
//  OpenWispher
//
//  Deepgram API client for speech-to-text transcription.
//

import Foundation

/// Client for Deepgram Speech-to-Text API
actor DeepgramAPIClient: TranscriptionProvider {
    let providerType: TranscriptionProviderType = .deepgram
    
    private let baseURL = "https://api.deepgram.com/v1/listen"
    nonisolated private var model: String {
        providerType.selectedAPIModelID
    }

    nonisolated private var language: String {
        providerType.selectedLanguageID(for: providerType.selectedModelID)
    }

    nonisolated private var shouldDetectLanguage: Bool {
        language == TranscriptionLanguageOption.autoID
    }
    
    nonisolated private var apiKey: String {
        // Prefer user-provided key from Secure Keychain, fall back to env var for dev.
        let stored = SecureStorage.retrieveAPIKey(for: .deepgram) ?? ""
        if !stored.isEmpty { return stored }
        return ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"] ?? ""
    }

    nonisolated var isConfigured: Bool {
        !apiKey.isEmpty
    }
    
    init() {
        // Intentionally empty – `apiKey` is read dynamically.
    }
    
    /// Transcribe audio data using Deepgram
    func transcribe(audioData: Data, fileName: String = "audio.m4a") async throws -> String {
        let key = apiKey
        guard !key.isEmpty else {
            throw TranscriptionError.missingAPIKey(provider: "Deepgram")
        }

        let languageLabel = shouldDetectLanguage ? "auto" : language
        print(
            "🎙️ Deepgram STT request: model=\(model) language=\(languageLabel) file=\(fileName) bytes=\(audioData.count)"
        )
        
        // Build URL with query parameters
        var components = URLComponents(string: baseURL)!
        var queryItems = [
            URLQueryItem(name: "model", value: model),
            URLQueryItem(name: "smart_format", value: "true"),
            URLQueryItem(name: "punctuate", value: "true"),
            URLQueryItem(name: "paragraphs", value: "true"),
        ]

        if shouldDetectLanguage {
            queryItems.append(URLQueryItem(name: "detect_language", value: "true"))
        } else {
            queryItems.append(URLQueryItem(name: "language", value: language))
        }

        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw TranscriptionError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/m4a", forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TranscriptionError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ Deepgram STT API error status \(httpResponse.statusCode): \(errorMessage)")
                throw TranscriptionError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
            
            // Parse response
            let transcriptionResponse = try JSONDecoder().decode(DeepgramResponse.self, from: data)
            
            // Extract transcript from results
            let text = transcriptionResponse.results?.channels?.first?.alternatives?.first?.transcript ?? ""
            
            guard !text.isEmpty else {
                throw TranscriptionError.emptyTranscription
            }
            
            return text
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.networkError(error)
        }
    }
}

// MARK: - Response Models

struct DeepgramResponse: Codable {
    let results: DeepgramResults?
}

struct DeepgramResults: Codable {
    let channels: [DeepgramChannel]?
}

struct DeepgramChannel: Codable {
    let alternatives: [DeepgramAlternative]?
}

struct DeepgramAlternative: Codable {
    let transcript: String
    let confidence: Double?
}
