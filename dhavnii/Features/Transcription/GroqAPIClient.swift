//
//  GroqAPIClient.swift
//  OpenWispher
//
//  Groq API client for Whisper transcription.
//

import Foundation

/// Client for Groq's Whisper API
actor GroqAPIClient: TranscriptionProvider {
    let providerType: TranscriptionProviderType = .groq

    private let baseURL = "https://api.groq.com/openai/v1/audio/transcriptions"

    /// Vocabulary and style hints forwarded to Whisper as the `prompt` field.
    /// Per Groq/Whisper guidance this field influences word choice, capitalization,
    /// and domain-specific terms only — the model still transcribes verbatim audio.
    private let transcriptionPrompt =
        "Preserve the speaker's exact words. Apply standard capitalization and punctuation. Use domain-specific spellings where context is clear (e.g. proper nouns, technical terms)."

    nonisolated private var model: String {
        providerType.selectedAPIModelID
    }

    nonisolated private var apiKey: String {
        // Prefer user-provided key from Secure Keychain, fall back to env var for dev.
        let stored = SecureStorage.retrieveAPIKey(for: .groq) ?? ""
        if !stored.isEmpty { return stored }
        return ProcessInfo.processInfo.environment["GROQ_API_KEY"] ?? ""
    }

    nonisolated var isConfigured: Bool {
        !apiKey.isEmpty
    }

    init() {
        // Intentionally empty – `apiKey` is read dynamically.
    }

    /// Transcribe audio data using Whisper.
    /// - Parameters:
    ///   - audioData: Raw audio bytes.
    ///   - fileName: Filename hint sent in the multipart body (default `"audio.m4a"`).
    ///   - preserveVerbatim: When `true` (default) the vocabulary/style prompt is
    ///     omitted, letting Whisper output its raw hypothesis with no additional
    ///     guidance.  Pass `false` to include the `transcriptionPrompt` hint so
    ///     Whisper applies the specified vocabulary and formatting preferences.
    func transcribe(
        audioData: Data,
        fileName: String = "audio.m4a",
        preserveVerbatim: Bool = true
    ) async throws -> String {
        let key = apiKey
        guard !key.isEmpty else {
            throw TranscriptionError.missingAPIKey(provider: "Groq")
        }

        print("🎙️ Groq STT request: model=\(model) file=\(fileName) bytes=\(audioData.count)")

        guard let url = URL(string: baseURL) else {
            throw TranscriptionError.invalidURL
        }

        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue(
            "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

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
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)

        // Add language field (English only)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("en\r\n".data(using: .utf8)!)

        // Optionally include vocabulary/style hint prompt (opt-in via preserveVerbatim = false)
        if !preserveVerbatim {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(transcriptionPrompt)\r\n".data(using: .utf8)!)
        }

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Groq STT API error status \(httpResponse.statusCode): \(errorMessage)")
            throw TranscriptionError.apiError(
                statusCode: httpResponse.statusCode, message: errorMessage)
        }

        // Parse response
        let transcriptionResponse = try JSONDecoder().decode(
            GroqTranscriptionResponse.self, from: data)
        return transcriptionResponse.text
    }
}

struct GroqTranscriptionResponse: Codable {
    let text: String
}
