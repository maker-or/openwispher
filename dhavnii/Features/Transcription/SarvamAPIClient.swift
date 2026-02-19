//
//  SarvamAPIClient.swift
//  OpenWispher
//
//  Sarvam AI client for Saaras speech-to-text transcription.
//

import Foundation

/// Client for Sarvam AI Speech-to-Text API (Saaras model)
actor SarvamAPIClient: TranscriptionProvider {
    let providerType: TranscriptionProviderType = .sarvam

    private let baseURL = "https://api.sarvam.ai/speech-to-text"

    nonisolated private var model: String {
        providerType.selectedAPIModelID
    }

    nonisolated private var language: String {
        providerType.selectedLanguageID(for: providerType.selectedModelID)
    }

    nonisolated private var apiKey: String {
        // Prefer user-provided key from Secure Keychain, fall back to env var for dev.
        let stored = SecureStorage.retrieveAPIKey(for: .sarvam) ?? ""
        if !stored.isEmpty { return stored }
        return ProcessInfo.processInfo.environment["SARVAM_API_KEY"] ?? ""
    }

    nonisolated var isConfigured: Bool {
        !apiKey.isEmpty
    }

    init() {
        // Intentionally empty – `apiKey` is read dynamically.
    }

    /// Transcribe audio data using Sarvam AI Saaras.
    func transcribe(audioData: Data, fileName: String) async throws -> String {
        let key = apiKey
        guard !key.isEmpty else {
            throw TranscriptionError.missingAPIKey(provider: "Sarvam")
        }

        let lang = language
        print(
            "🎙️ Sarvam STT request: model=\(model) language=\(lang) file=\(fileName) bytes=\(audioData.count)"
        )

        guard let url = URL(string: baseURL) else {
            throw TranscriptionError.invalidURL
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "api-subscription-key")
        request.setValue(
            "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // File field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n"
                .data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)

        // Language field — "unknown" tells the API to auto-detect; never omit it
        let langCode = lang == TranscriptionLanguageOption.autoID ? "unknown" : lang
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"language_code\"\r\n\r\n"
                .data(using: .utf8)!)
        body.append("\(langCode)\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TranscriptionError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ Sarvam STT API error status \(httpResponse.statusCode): \(errorMessage)")
                throw TranscriptionError.apiError(
                    statusCode: httpResponse.statusCode, message: errorMessage)
            }

            let transcriptionResponse = try JSONDecoder().decode(
                SarvamTranscriptionResponse.self, from: data)

            let text = transcriptionResponse.transcript
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

// MARK: - Response Model

private struct SarvamTranscriptionResponse: Codable {
    let requestId: String?
    let transcript: String
    let languageCode: String?

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case transcript
        case languageCode = "language_code"
    }
}
