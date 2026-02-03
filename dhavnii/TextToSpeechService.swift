//
//  TextToSpeechService.swift
//  OpenWispher
//
//  Orchestrates text-to-speech generation and playback.
//

import Foundation

@MainActor
@Observable
internal final class TextToSpeechService {
    private var groqTTSClient = GroqTTSClient()
    private var deepgramTTSClient = DeepgramTTSClient()
    private var elevenLabsTTSClient = ElevenLabsTTSClient()
    private var openAITTSClient = OpenAITTSClient()
    private let audioPlayer = TTSAudioPlayer()

    internal var selectedProvider: TTSProviderType
    internal var appState: AppState

    internal init(appState: AppState, selectedProvider: TTSProviderType = .groq) {
        self.appState = appState
        self.selectedProvider = selectedProvider
    }

    internal func speak(text: String, provider: TTSProviderType? = nil) async {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            appState.ttsState = .error(message: "Empty text")
            return
        }

        print("🔊 TTS request: provider=\((provider ?? selectedProvider).rawValue) textLength=\(trimmedText.count)")
        appState.currentlySpeaking = trimmedText
        appState.ttsState = .generating
        appState.ttsProgress = 0.0
        // IMPORTANT: Do not show the notch during generation. The notch should appear
        // only once we have audio data and playback starts.
        appState.showTTSNotch = false

        let selected = provider ?? selectedProvider

        do {
            let audioData = try await synthesize(text: trimmedText, provider: selected)
            // Now that we have audio, show the notch for playback.
            appState.showTTSNotch = true
            appState.ttsState = .speaking
            appState.ttsProgress = 0.5

            try audioPlayer.play(audioData: audioData) { [weak self] in
                guard let self else { return }
                self.appState.ttsState = .idle
                self.appState.ttsProgress = 1.0
                // Do NOT auto-close the pill. User closes it via the X button.
            }
        } catch {
            let message = (error as? TTSError)?.localizedDescription ?? "TTS error"
            print("❌ TTS error: \(message)")
            appState.ttsState = .error(message: String(message.prefix(40)))
            appState.showTTSNotch = false
        }
    }

    internal func pauseSpeaking() {
        audioPlayer.pause()
        appState.ttsState = .paused
    }

    internal func resumeSpeaking() {
        audioPlayer.resume()
        appState.ttsState = .speaking
    }

    internal func stopSpeaking() {
        audioPlayer.stop()
        appState.ttsState = .idle
        // Do NOT auto-close the pill. User closes it via the X button.
    }

    private func synthesize(text: String, provider: TTSProviderType) async throws -> Data {
        switch provider {
        case .groq:
            return try await groqTTSClient.synthesize(text: text)
        case .deepgram:
            return try await deepgramTTSClient.synthesize(text: text)
        case .elevenLabs:
            return try await elevenLabsTTSClient.synthesize(text: text)
        case .openAI:
            return try await openAITTSClient.synthesize(text: text)
        }
    }
}
