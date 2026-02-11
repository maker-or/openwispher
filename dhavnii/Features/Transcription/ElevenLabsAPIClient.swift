//
//  ElevenLabsAPIClient.swift
//  OpenWispher
//
//  ElevenLabs API client for speech-to-text transcription.
//

import Foundation

/// Client for ElevenLabs Speech-to-Text API
actor ElevenLabsAPIClient: TranscriptionProvider {
    let providerType: TranscriptionProviderType = .elevenLabs

    private let baseURL = "https://api.elevenlabs.io/v1/speech-to-text"
    nonisolated private var model: String {
        providerType.selectedAPIModelID
    }

    nonisolated private var language: String {
        providerType.selectedLanguageID(for: providerType.selectedModelID)
    }

    nonisolated private var shouldAutoDetectLanguage: Bool {
        language == TranscriptionLanguageOption.autoID
    }

    nonisolated private var apiKey: String {
        // Prefer user-provided key from Secure Keychain, fall back to env var for dev.
        let stored = SecureStorage.retrieveAPIKey(for: .elevenLabs) ?? ""
        if !stored.isEmpty { return stored }
        return ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"] ?? ""
    }

    nonisolated var isConfigured: Bool {
        !apiKey.isEmpty
    }

    init() {
        // Intentionally empty – `apiKey` is read dynamically.
    }

    /// Transcribe audio data using ElevenLabs
    func transcribe(audioData: Data, fileName: String = "audio.m4a") async throws -> String {
        let key = apiKey
        guard !key.isEmpty else {
            throw TranscriptionError.missingAPIKey(provider: "ElevenLabs")
        }

        let languageLabel = shouldAutoDetectLanguage ? "auto" : language
        print(
            "🎙️ ElevenLabs STT request: model=\(model) language=\(languageLabel) file=\(fileName) bytes=\(audioData.count)"
        )

        guard let url = URL(string: baseURL) else {
            throw TranscriptionError.invalidURL
        }

        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "xi-api-key")

        var body = Data()

        // Add file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(
                using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Add model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)

        // Add language field (auto-detect when omitted)
        if !shouldAutoDetectLanguage {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append(
                "Content-Disposition: form-data; name=\"language_code\"\r\n\r\n".data(
                    using: .utf8)!)
            body.append("\(language)\r\n".data(using: .utf8)!)
        }

        // Add tag audio events field (optional, but useful)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"tag_audio_events\"\r\n\r\n".data(using: .utf8)!)
        body.append("true\r\n".data(using: .utf8)!)

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TranscriptionError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print(
                    "❌ ElevenLabs STT API error status \(httpResponse.statusCode): \(errorMessage)")
                throw TranscriptionError.apiError(
                    statusCode: httpResponse.statusCode, message: errorMessage)
            }

            // Parse response
            let transcriptionResponse = try JSONDecoder().decode(
                ElevenLabsResponse.self, from: data)

            // Combine all text from words
            let text = transcriptionResponse.words.map { $0.text }.joined(separator: " ")

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

struct ElevenLabsResponse: Codable {
    let languageCode: String
    let languageProbability: Double
    let text: String?
    let words: [ElevenLabsWord]

    enum CodingKeys: String, CodingKey {
        case languageCode = "language_code"
        case languageProbability = "language_probability"
        case text
        case words
    }
}

struct ElevenLabsWord: Codable {
    let text: String
    let start: Double
    let end: Double
    let type: String
}
