//
//  CLIHandler.swift
//  OpenWispher
//
//  Handles CLI-triggered TTS requests via distributed notifications.
//

import Foundation

@MainActor
internal final class CLIHandler {
    private let ttsService: TextToSpeechService
    private var observer: NSObjectProtocol?

    internal init(ttsService: TextToSpeechService) {
        self.ttsService = ttsService
        startListening()
    }

    deinit {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    private func startListening() {
        let notificationName = Notification.Name("OpenWispher.TTS.Request")
        observer = DistributedNotificationCenter.default().addObserver(
            forName: notificationName,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let userInfo = notification.userInfo else { return }

            let text = userInfo["text"] as? String ?? ""
            let providerRaw = (userInfo["provider"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

            let provider = providerRaw.flatMap { rawValue in
                if let exact = TTSProviderType(rawValue: rawValue) {
                    return exact
                }
                let normalized = rawValue.lowercased()
                return TTSProviderType.allCases.first { $0.rawValue.lowercased() == normalized }
            }
            Task {
                await self.ttsService.speak(text: text, provider: provider)
            }
        }
    }
}
