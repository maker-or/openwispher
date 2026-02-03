//
//  OpenAITTSClient.swift
//  OpenWispher
//
//  OpenAI API client for text-to-speech.
//

import Foundation

/// Client for OpenAI TTS API
actor OpenAITTSClient: TextToSpeechProvider {
    let providerType: TTSProviderType = .openAI

    private let baseURL = "https://api.openai.com/v1/audio/speech"
    private let model = "tts-1"

    private var apiKey: String {
        let stored = SecureStorage.retrieveTTSAPIKey(for: .openAI) ?? ""
        if !stored.isEmpty { return stored }
        return ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    }

    var isConfigured: Bool {
        !apiKey.isEmpty
    }

    init() {
        // Intentionally empty – `apiKey` is read dynamically.
    }

    func synthesize(text: String) async throws -> Data {
        let key = apiKey
        guard !key.isEmpty else {
            throw TTSError.missingAPIKey(provider: "OpenAI")
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TTSError.invalidText
        }
        guard let url = URL(string: baseURL) else {
            throw TTSError.invalidURL
        }

        print("🔊 OpenAI TTS request: model=\(model) chars=\(text.count)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
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
                print("❌ OpenAI TTS API error status \(httpResponse.statusCode): \(errorMessage)")
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
