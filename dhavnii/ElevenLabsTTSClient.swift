//
//  ElevenLabsTTSClient.swift
//  OpenWispher
//
//  ElevenLabs API client for text-to-speech.
//

import Foundation

/// Client for ElevenLabs TTS API
actor ElevenLabsTTSClient: TextToSpeechProvider {
    let providerType: TTSProviderType = .elevenLabs

    private let baseURL = "https://api.elevenlabs.io/v1/text-to-speech"
    private let model = "eleven_monolingual_v1"
    // ElevenLabs requires a voice in the request path; we use a fixed default.
    private let defaultVoiceId = "21m00Tcm4TlvDq8ikWAM" // Rachel

    private var apiKey: String {
        let stored = SecureStorage.retrieveTTSAPIKey(for: .elevenLabs) ?? ""
        if !stored.isEmpty { return stored }
        return ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"] ?? ""
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
            throw TTSError.missingAPIKey(provider: "ElevenLabs")
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TTSError.invalidText
        }

        print("🔊 ElevenLabs TTS request: model=eleven_multilingual_v2 chars=\(text.count)")
        guard let url = URL(string: "\(baseURL)/\(defaultVoiceId)") else {
            throw TTSError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let payload: [String: Any] = [
            "text": text,
            "model_id": "eleven_multilingual_v2"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TTSError.invalidResponse
            }
            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ ElevenLabs TTS API error status \(httpResponse.statusCode): \(errorMessage)")
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
