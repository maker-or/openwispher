//
//  TranscriptionService.swift
//  OpenWispher
//
//  Orchestrates the complete transcription flow with timeout and fallback support.
//

import Foundation

/// Orchestrates recording, transcription, and output
@MainActor
@Observable
internal class TranscriptionService {
    private let audioRecorder = AudioRecorder()
    private let clipboardManager = ClipboardManager()

    private var groqClient = GroqAPIClient()
    private var elevenLabsClient = ElevenLabsAPIClient()
    private var deepgramClient = DeepgramAPIClient()

    // selectedProvider is still injected at startup but is now also re-read live from
    // UserDefaults on every transcription attempt so that Settings changes take effect
    // immediately without requiring an app restart.
    internal var selectedProvider: TranscriptionProviderType
    internal var appState: AppState
    internal var historyManager: HistoryManager?

    /// Notification posted when a new transcription is saved
    internal static let transcriptionSavedNotification = Notification.Name(
        "OpenWispher.TranscriptionSaved")

    internal init(appState: AppState, selectedProvider: TranscriptionProviderType = .groq) {
        self.appState = appState
        self.selectedProvider = selectedProvider
    }

    // MARK: - Recording control

    /// Start the recording session
    internal func startRecording() {
        print("🎤 TranscriptionService.startRecording() called")
        print("   Current appState.recordingState: \(appState.recordingState)")
        print("   AudioRecorder.isRecording: \(audioRecorder.isRecording)")

        do {
            try audioRecorder.startRecording()
            appState.recordingState = .recording
            print("✅ Recording started successfully, state set to .recording")
        } catch {
            print("❌ Failed to start recording: \(error)")
            appState.recordingState = .error(message: "Mic error")
            FeedbackManager.shared.showRecordingError()
            resetAfterDelay()
        }
    }

    /// Stop recording and process transcription
    internal func stopRecording() {
        print("⏹️ TranscriptionService.stopRecording() called")
        print("   Current appState.recordingState: \(appState.recordingState)")
        print("   AudioRecorder.isRecording: \(audioRecorder.isRecording)")

        guard audioRecorder.isRecording else {
            print("⚠️ stopRecording() called but audioRecorder.isRecording is false - ignoring")
            return
        }

        _ = audioRecorder.stopRecording()
        appState.recordingState = .processing
        print("✅ Recording stopped, state set to .processing")

        Task {
            await processTranscription()
        }
    }

    /// Cancel recording and discard audio without transcribing
    internal func cancelRecording() {
        print("⏹️ TranscriptionService.cancelRecording() called")
        print("   Current appState.recordingState: \(appState.recordingState)")
        print("   AudioRecorder.isRecording: \(audioRecorder.isRecording)")

        guard audioRecorder.isRecording else {
            print(
                "⚠️ cancelRecording() called but audioRecorder.isRecording is false - ignoring")
            return
        }

        _ = audioRecorder.stopRecording()
        audioRecorder.deleteRecording()
        appState.recordingState = .idle
    }

    // MARK: - Transcription orchestration

    /// Full pipeline: read audio → try primary → try fallback on eligible error → deliver result.
    private func processTranscription() async {
        // The disk file is deleted after this function exits regardless of outcome.
        // audioData below is an in-memory copy, so both primary and fallback calls
        // can use it even though the file is gone by the time defer fires.
        defer {
            audioRecorder.deleteRecording()
        }

        guard let audioData = audioRecorder.getRecordingData() else {
            appState.recordingState = .error(message: "No audio")
            FeedbackManager.shared.showEmptyRecordingWarning()
            resetAfterDelay()
            return
        }

        // Re-read the primary provider live from UserDefaults so that changes made
        // in Settings are reflected without restarting the app.
        let primary = liveSelectedProvider()
        let fallback = TranscriptionProviderType.savedFallbackProvider
        let timeoutSeconds = TranscriptionProviderType.savedTimeoutSeconds

        print(
            "🎙️ STT request: primary=\(primary.rawValue), fallback=\(fallback?.rawValue ?? "none"), timeout=\(timeoutSeconds)s"
        )

        do {
            let transcription = try await attempt(
                provider: primary,
                audioData: audioData,
                timeoutSeconds: timeoutSeconds
            )
            try await deliver(transcription: transcription, provider: primary)
        } catch let primaryError {
            print("⚠️ Primary provider \(primary.rawValue) failed: \(primaryError)")

            // Determine whether to try the fallback
            let eligibleForFallback = (primaryError as? TranscriptionError)?.shouldTryFallback ?? true

            if eligibleForFallback, let fallback, fallback != primary {
                print("🔄 Trying fallback provider: \(fallback.rawValue)")
                do {
                    let transcription = try await attempt(
                        provider: fallback,
                        audioData: audioData,
                        timeoutSeconds: timeoutSeconds
                    )
                    // Successful fallback — track analytics silently, no user-facing notice
                    AnalyticsManager.shared.trackFallbackUsed(
                        primary: primary,
                        fallback: fallback,
                        reason: (primaryError as? TranscriptionError)?.analyticsReason ?? "unknown"
                    )
                    try await deliver(transcription: transcription, provider: fallback)
                } catch let fallbackError {
                    print("❌ Fallback provider \(fallback.rawValue) also failed: \(fallbackError)")
                    surfaceError(fallbackError)
                }
            } else {
                surfaceError(primaryError)
            }
        }
    }

    // MARK: - Single-attempt helper

    /// Calls `provider.transcribe` and cancels it if it exceeds `timeoutSeconds`.
    /// Throws `TranscriptionError.timeout` when the deadline is exceeded.
    private func attempt(
        provider providerType: TranscriptionProviderType,
        audioData: Data,
        timeoutSeconds: Double
    ) async throws -> String {
        let client = client(for: providerType)

        return try await withThrowingTaskGroup(of: String.self) { group in
            // Transcription task
            group.addTask {
                try await client.transcribe(audioData: audioData, fileName: "audio.m4a")
            }

            // Timeout watchdog
            let timeoutNS = UInt64(timeoutSeconds * 1_000_000_000)
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNS)
                throw TranscriptionError.timeout(provider: providerType.rawValue)
            }

            // Whichever finishes first wins; cancel the other
            do {
                let result = try await group.next()!
                group.cancelAll()
                return result
            } catch {
                group.cancelAll()
                throw error
            }
        }
    }

    // MARK: - Delivery

    /// Validates the transcription text, copies it to clipboard, saves to history, updates state.
    private func deliver(transcription: String, provider: TranscriptionProviderType) async throws {
        guard !transcription.isEmpty else {
            appState.recordingState = .error(message: "Empty result")
            FeedbackManager.shared.showEmptyRecordingWarning()
            resetAfterDelay()
            return
        }

        clipboardManager.copyAndPasteIfPossible(transcription)

        historyManager?.saveTranscription(text: transcription, provider: provider)

        NotificationCenter.default.post(name: Self.transcriptionSavedNotification, object: nil)

        appState.lastTranscription = transcription
        appState.recordingState = .success
        FeedbackManager.shared.showTranscriptionSuccess()
        resetAfterDelay(seconds: 1.5)
    }

    // MARK: - Error surface

    private func surfaceError(_ error: Error) {
        let userMessage = error.userFriendlyMessage
        appState.recordingState = .error(message: String(userMessage.prefix(20)))
        FeedbackManager.shared.showAPIError(userMessage)
        resetAfterDelay()
    }

    // MARK: - Utilities

    private func client(for providerType: TranscriptionProviderType) -> any TranscriptionProvider {
        switch providerType {
        case .groq: return groqClient
        case .elevenLabs: return elevenLabsClient
        case .deepgram: return deepgramClient
        }
    }

    /// Reads the primary provider live from UserDefaults, falling back to the injected value.
    private func liveSelectedProvider() -> TranscriptionProviderType {
        guard
            let raw = UserDefaults.standard.string(
                forKey: "selectedTranscriptionProvider"),
            let live = TranscriptionProviderType(rawValue: raw)
        else { return selectedProvider }
        selectedProvider = live
        return live
    }

    /// Reset to idle state after a delay
    private func resetAfterDelay(seconds: Double = 2.0) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            appState.recordingState = .idle
        }
    }
}

// MARK: - TranscriptionError analytics helper

private extension TranscriptionError {
    var analyticsReason: String {
        switch self {
        case .timeout: return "timeout"
        case .apiError(let code, _): return code == 429 ? "rate_limit" : "api_error_\(code)"
        case .networkError: return "network_error"
        default: return "error"
        }
    }
}
