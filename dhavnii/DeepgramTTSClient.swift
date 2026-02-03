//
//  DeepgramTTSClient.swift
//  OpenWispher
//
//  Deepgram API client for text-to-speech.
//

import Foundation

/// Client for Deepgram TTS API
actor DeepgramTTSClient: TextToSpeechProvider {
    let providerType: TTSProviderType = .deepgram

    private let baseURL = "https://api.deepgram.com/v1/speak"

    private var apiKey: String {
        let stored = SecureStorage.retrieveTTSAPIKey(for: .deepgram) ?? ""
        if !stored.isEmpty { return stored }
        return ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"] ?? ""
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
            throw TTSError.missingAPIKey(provider: "Deepgram")
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TTSError.invalidText
        }
        print("🔊 Deepgram TTS request: chars=\(text.count)")

        guard let url = URL(string: baseURL) else {
            throw TTSError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let payload: [String: Any] = [
            "text": text
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TTSError.invalidResponse
            }
            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ Deepgram TTS API error status \(httpResponse.statusCode): \(errorMessage)")
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
