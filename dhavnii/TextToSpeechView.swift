//
//  TextToSpeechView.swift
//  OpenWispher
//
//  UI for text-to-speech generation and playback.
//

import SwiftUI

internal struct TextToSpeechView: View {
    @State private var inputText = ""

    @AppStorage("selectedTTSProvider") private var selectedProviderRaw = TTSProviderType.groq.rawValue

    var ttsService: TextToSpeechService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Text to Speech")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Text")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    TextEditor(text: $inputText)
                        .font(.system(size: 14))
                        .frame(height: 160)
                        .padding(10)
                        .liquidGlassSurface(cornerRadius: 10, interactive: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Provider")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Picker("Provider", selection: $selectedProviderRaw) {
                        ForEach(TTSProviderType.allCases) { provider in
                            Text(provider.displayName).tag(provider.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedProviderRaw) { _, newValue in
                        let provider = TTSProviderType(rawValue: newValue) ?? .groq
                        ttsService.selectedProvider = provider
                    }
                }

                HStack(spacing: 12) {
                    Button("Speak") {
                        Task {
                            await ttsService.speak(
                                text: inputText,
                                provider: selectedProvider
                            )
                        }
                    }
                    .liquidGlassButtonStyle(prominent: true)
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Pause") {
                        ttsService.pauseSpeaking()
                    }
                    .liquidGlassButtonStyle()

                    Button("Resume") {
                        ttsService.resumeSpeaking()
                    }
                    .liquidGlassButtonStyle()

                    Button("Stop") {
                        ttsService.stopSpeaking()
                    }
                    .liquidGlassButtonStyle()

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("CLI Usage")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text("openwispher-speak \"Hello, I am an AI agent\"")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .liquidGlassSurface(cornerRadius: 8)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
        }
        .onAppear {
            Task {
                ttsService.selectedProvider = selectedProvider
            }
        }
    }

    private var selectedProvider: TTSProviderType {
        TTSProviderType(rawValue: selectedProviderRaw) ?? .groq
    }
}
