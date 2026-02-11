//
//  TranscriptionService.swift
//  OpenWispher
//
//  Orchestrates the complete transcription flow.
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
    
    internal var selectedProvider: TranscriptionProviderType
    internal var appState: AppState
    internal var historyManager: HistoryManager?
    
    /// Notification posted when a new transcription is saved
    internal static let transcriptionSavedNotification = Notification.Name("OpenWispher.TranscriptionSaved")

    internal init(appState: AppState, selectedProvider: TranscriptionProviderType = .groq) {
        self.appState = appState
        self.selectedProvider = selectedProvider
    }

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

    /// Cancel recording and discard audio without saving
    internal func cancelRecording() {
        print("⏹️ TranscriptionService.cancelRecording() called")
        print("   Current appState.recordingState: \(appState.recordingState)")
        print("   AudioRecorder.isRecording: \(audioRecorder.isRecording)")

        guard audioRecorder.isRecording else {
            print("⚠️ cancelRecording() called but audioRecorder.isRecording is false - ignoring")
            return
        }

        _ = audioRecorder.stopRecording()
        audioRecorder.deleteRecording()
        appState.recordingState = .idle
    }

    /// Process the recorded audio through the selected provider
    private func processTranscription() async {
        defer {
            // Always clean up the audio file
            audioRecorder.deleteRecording()
        }

        guard let audioData = audioRecorder.getRecordingData() else {
            appState.recordingState = .error(message: "No audio")
            FeedbackManager.shared.showEmptyRecordingWarning()
            resetAfterDelay()
            return
        }

        let provider: TranscriptionProvider
        switch selectedProvider {
        case .groq:
            provider = groqClient
        case .elevenLabs:
            provider = elevenLabsClient
        case .deepgram:
            provider = deepgramClient
        }

        do {
            print("🎙️ STT request: provider=\(selectedProvider.rawValue)")
            let transcription = try await provider.transcribe(audioData: audioData, fileName: "audio.m4a")

            if transcription.isEmpty {
                appState.recordingState = .error(message: "Empty result")
                FeedbackManager.shared.showEmptyRecordingWarning()
                resetAfterDelay()
                return
            }

            // Copy to clipboard and auto-paste if possible
            clipboardManager.copyAndPasteIfPossible(transcription)

            // Save to history after successful transcription
            historyManager?.saveTranscription(
                text: transcription,
                provider: selectedProvider
            )
            
            // Post notification for UI refresh (event-driven instead of polling)
            NotificationCenter.default.post(name: Self.transcriptionSavedNotification, object: nil)

            appState.lastTranscription = transcription
            appState.recordingState = .success
            FeedbackManager.shared.showTranscriptionSuccess()
            resetAfterDelay(seconds: 1.5)

        } catch {
            let userMessage = error.userFriendlyMessage
            appState.recordingState = .error(message: String(userMessage.prefix(20)))
            FeedbackManager.shared.showAPIError(userMessage)
            resetAfterDelay()
        }
    }

    /// Reset to idle state after a delay
    private func resetAfterDelay(seconds: Double = 2.0) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            appState.recordingState = .idle
        }
    }
}
