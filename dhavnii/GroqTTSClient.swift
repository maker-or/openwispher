//
//  GroqTTSClient.swift
//  OpenWispher
//
//  Groq API client for text-to-speech.
//

import Foundation

/// Client for Groq TTS API (OpenAI-compatible)
actor GroqTTSClient: TextToSpeechProvider {
    let providerType: TTSProviderType = .groq

    private let baseURL = "https://api.groq.com/openai/v1/audio/speech"
    private let model = "canopylabs/orpheus-v1-english"

    private var apiKeySource: (value: String, source: String) {
        let stored = SecureStorage.retrieveTTSAPIKey(for: .groq) ?? ""
        if !stored.isEmpty {
            return (stored, "keychain")
        }
        let envKey = ProcessInfo.processInfo.environment["GROQ_API_KEY"] ?? ""
        if !envKey.isEmpty {
            return (envKey, "env")
        }
        return ("", "missing")
    }

    var isConfigured: Bool {
        !apiKeySource.value.isEmpty
    }

    init() {
        // Intentionally empty – `apiKey` is read dynamically.
    }

    func synthesize(text: String) async throws -> Data {
        let keySource = apiKeySource
        guard !keySource.value.isEmpty else {
            throw TTSError.missingAPIKey(provider: "Groq")
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TTSError.invalidText
        }

        print("🔊 Groq TTS request: model=\(model) chars=\(text.count) keySource=\(keySource.source)")
        guard let url = URL(string: baseURL) else {
            throw TTSError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(keySource.value)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let payload: [String: Any] = [
            "model": model,
            "input": text,
            "response_format": "mp3"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TTSError.invalidResponse
            }
            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ Groq TTS API error (source: \(keySource.source)) status \(httpResponse.statusCode): \(errorMessage)")
                throw TTSError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
            guard !data.isEmpty else {
                throw TTSError.emptyAudio
            }
            return data
        } catch let error as TTSError {
            throw error
        } catch {
            throw TTSError.networkError(error)
        }
    }
}
