//
//  TranscriptionProvider.swift
//  OpenWispher
//
//  Protocol and types for multiple transcription providers.
//

import Foundation

/// Supported transcription providers
enum TranscriptionProviderType: String, CaseIterable, Identifiable {
    case groq = "Groq"
    case elevenLabs = "ElevenLabs"
    case deepgram = "Deepgram"
    case sarvam = "Sarvam"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .groq: return "Groq (Whisper)"
        case .elevenLabs: return "ElevenLabs"
        case .deepgram: return "Deepgram"
        case .sarvam: return "Sarvam AI"
        }
    }
    
    var description: String {
        switch self {
        case .groq:
            return "Fast Whisper-based transcription with competitive pricing"
        case .elevenLabs:
            return "High-quality speech-to-text with advanced features"
        case .deepgram:
            return "Enterprise-grade transcription with real-time capabilities"
        case .sarvam:
            return "Indian-language-first speech-to-text powered by Saaras"
        }
    }
}

struct TranscriptionModelOption: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
}

struct TranscriptionLanguageOption: Identifiable, Hashable {
    nonisolated static let autoID = "auto"

    let id: String
    let name: String
    let description: String

    var isAuto: Bool {
        id == Self.autoID
    }
}

extension TranscriptionProviderType {
    // MARK: - Fallback & timeout UserDefaults keys

    /// UserDefaults key that stores the raw value of the fallback provider ("" = disabled).
    nonisolated static let fallbackProviderDefaultsKey = "fallbackTranscriptionProvider"

    /// UserDefaults key that stores the per-attempt timeout in seconds (Double).
    nonisolated static let timeoutSecondsDefaultsKey = "transcriptionTimeoutSeconds"

    /// Default timeout before falling back to the secondary provider (seconds).
    nonisolated static let defaultTimeoutSeconds: Double = 8

    /// The currently saved fallback provider, or nil when disabled.
    nonisolated static var savedFallbackProvider: TranscriptionProviderType? {
        guard let raw = UserDefaults.standard.string(forKey: fallbackProviderDefaultsKey),
              !raw.isEmpty
        else { return nil }
        return TranscriptionProviderType(rawValue: raw)
    }

    /// The currently saved timeout (seconds). Falls back to the default if unset.
    nonisolated static var savedTimeoutSeconds: Double {
        let stored = UserDefaults.standard.double(forKey: timeoutSecondsDefaultsKey)
        return stored > 0 ? stored : defaultTimeoutSeconds
    }

    // MARK: - Existing keys (model / language)

    nonisolated var modelUserDefaultsKey: String {
        switch self {
        case .groq:
            return "selectedGroqTranscriptionModel"
        case .elevenLabs:
            return "selectedElevenLabsTranscriptionModel"
        case .deepgram:
            return "selectedDeepgramTranscriptionModel"
        case .sarvam:
            return "selectedSarvamTranscriptionModel"
        }
    }

    nonisolated var defaultModelID: String {
        switch self {
        case .groq:
            return "whisper-large-v3"
        case .elevenLabs:
            return "scribe_v2"
        case .deepgram:
            return "nova-3"
        case .sarvam:
            return "saaras:v3"
        }
    }

    nonisolated var modelOptions: [TranscriptionModelOption] {
        switch self {
        case .groq:
            return [
                TranscriptionModelOption(
                    id: "whisper-large-v3",
                    name: "Whisper Large v3",
                    description: "General-purpose OpenAI Whisper model via Groq"
                )
            ]
        case .elevenLabs:
            return [
                TranscriptionModelOption(
                    id: "scribe_v2",
                    name: "scribe_v2",
                    description: "State-of-the-art speech recognition model"
                ),
                TranscriptionModelOption(
                    id: "scribe_v1",
                    name: "scribe_v1",
                    description: "Previous generation model, generally superseded by v2"
                ),
            ]
        case .deepgram:
            return [
                TranscriptionModelOption(
                    id: "flux",
                    name: "Flux",
                    description:
                        "Streaming model with native turn detection for real-time conversations"
                ),
                TranscriptionModelOption(
                    id: "nova-3",
                    name: "nova-3",
                    description:
                        "Highest-performing general ASR for meetings, noisy and multi-speaker audio"
                ),
                TranscriptionModelOption(
                    id: "nova-2",
                    name: "nova-2",
                    description:
                        "Recommended for languages not yet supported by nova-3 and filler words"
                ),
            ]
        case .sarvam:
            return [
                TranscriptionModelOption(
                    id: "saaras:v3",
                    name: "Saaras v3",
                    description: "Latest Sarvam model, recommended for all Indian languages"
                ),
                TranscriptionModelOption(
                    id: "saaras:v2.5",
                    name: "Saaras v2.5",
                    description: "Previous generation model"
                ),
            ]
        }
    }

    nonisolated var languageUserDefaultsKey: String {
        switch self {
        case .groq:
            return "selectedGroqTranscriptionLanguage"
        case .elevenLabs:
            return "selectedElevenLabsTranscriptionLanguage"
        case .deepgram:
            return "selectedDeepgramTranscriptionLanguage"
        case .sarvam:
            return "selectedSarvamTranscriptionLanguage"
        }
    }

    nonisolated var selectedModelID: String {
        let storedModel = UserDefaults.standard.string(forKey: modelUserDefaultsKey)
        return resolveModelID(storedModel)
    }

    nonisolated var selectedAPIModelID: String {
        apiModelID(for: selectedModelID)
    }

    nonisolated func selectedLanguageID(for modelID: String? = nil) -> String {
        let resolvedModel = resolveModelID(modelID)
        let storedLanguage = UserDefaults.standard.string(forKey: languageUserDefaultsKey)
        return resolveLanguageID(storedLanguage, modelID: resolvedModel)
    }

    nonisolated func defaultLanguageID(for modelID: String? = nil) -> String {
        let resolvedModel = resolveModelID(modelID)
        switch self {
        case .groq:
            return TranscriptionLanguageOption.autoID
        case .elevenLabs:
            return TranscriptionLanguageOption.autoID
        case .deepgram:
            return resolvedModel == "flux" ? "en" : TranscriptionLanguageOption.autoID
        case .sarvam:
            return TranscriptionLanguageOption.autoID
        }
    }

    nonisolated func languageOptions(for modelID: String? = nil) -> [TranscriptionLanguageOption] {
        let resolvedModel = resolveModelID(modelID)

        switch self {
        case .groq:
            return [
                TranscriptionLanguageOption(
                    id: TranscriptionLanguageOption.autoID,
                    name: "Auto",
                    description: "Model selects the language from audio"
                )
            ]

        case .elevenLabs:
            return [
                TranscriptionLanguageOption(
                    id: TranscriptionLanguageOption.autoID,
                    name: "Auto",
                    description: "Automatically detect language from audio"
                )
            ] + Self.expandLanguageGroups(Self.elevenLabsLanguageGroups)

        case .deepgram:
            switch resolvedModel {
            case "flux":
                return [
                    TranscriptionLanguageOption(
                        id: "en",
                        name: "English",
                        description: "Flux supports English"
                    )
                ]
            case "nova-2":
                return [
                    TranscriptionLanguageOption(
                        id: TranscriptionLanguageOption.autoID,
                        name: "Auto",
                        description: "Detect dominant language from audio"
                    )
                ] + Self.expandLanguageGroups(Self.deepgramNova2LanguageGroups)
            default:
                return [
                    TranscriptionLanguageOption(
                        id: TranscriptionLanguageOption.autoID,
                        name: "Auto",
                        description: "Detect dominant language from audio"
                    )
                ] + Self.expandLanguageGroups(Self.deepgramNova3LanguageGroups)
            }

        case .sarvam:
            return [
                TranscriptionLanguageOption(
                    id: TranscriptionLanguageOption.autoID,
                    name: "Auto",
                    description: "Automatically detect language from audio"
                ),
                TranscriptionLanguageOption(id: "hi-IN", name: "Hindi", description: "Locale code: hi-IN"),
                TranscriptionLanguageOption(id: "bn-IN", name: "Bengali", description: "Locale code: bn-IN"),
                TranscriptionLanguageOption(id: "kn-IN", name: "Kannada", description: "Locale code: kn-IN"),
                TranscriptionLanguageOption(id: "ml-IN", name: "Malayalam", description: "Locale code: ml-IN"),
                TranscriptionLanguageOption(id: "mr-IN", name: "Marathi", description: "Locale code: mr-IN"),
                TranscriptionLanguageOption(id: "od-IN", name: "Odia", description: "Locale code: od-IN"),
                TranscriptionLanguageOption(id: "pa-IN", name: "Punjabi", description: "Locale code: pa-IN"),
                TranscriptionLanguageOption(id: "ta-IN", name: "Tamil", description: "Locale code: ta-IN"),
                TranscriptionLanguageOption(id: "te-IN", name: "Telugu", description: "Locale code: te-IN"),
                TranscriptionLanguageOption(id: "gu-IN", name: "Gujarati", description: "Locale code: gu-IN"),
                TranscriptionLanguageOption(id: "en-IN", name: "English (India)", description: "Locale code: en-IN"),
            ]
        }
    }

    nonisolated func apiModelID(for modelID: String) -> String {
        switch self {
        case .deepgram:
            return modelID == "flux" ? "flux-general-en" : modelID
        case .groq, .elevenLabs, .sarvam:
            return modelID
        }
    }

    nonisolated func resolveModelID(_ value: String?) -> String {
        guard let value, modelOptions.contains(where: { $0.id == value }) else {
            return defaultModelID
        }
        return value
    }

    nonisolated func resolveLanguageID(_ value: String?, modelID: String? = nil) -> String {
        let resolvedModel = resolveModelID(modelID)
        let options = languageOptions(for: resolvedModel)

        guard let value, options.contains(where: { $0.id == value }) else {
            return defaultLanguageID(for: resolvedModel)
        }

        return value
    }

    nonisolated private static func expandLanguageGroups(_ groups: [(String, [String])]) -> [
        TranscriptionLanguageOption
    ] {
        groups.flatMap { languageName, codes in
            codes.map { code in
                TranscriptionLanguageOption(
                    id: code,
                    name: codes.count == 1 ? languageName : "\(languageName) (\(code))",
                    description: "Locale code: \(code)"
                )
            }
        }
    }

    nonisolated private static let deepgramNova3LanguageGroups: [(String, [String])] = [
        ("Arabic", ["ar", "ar-AE", "ar-SA", "ar-QA", "ar-KW", "ar-SY", "ar-LB", "ar-PS", "ar-JO", "ar-EG", "ar-SD", "ar-TD", "ar-MA", "ar-DZ", "ar-TN", "ar-IQ", "ar-IR"]),
        ("Belarusian", ["be"]),
        ("Bengali", ["bn"]),
        ("Bosnian", ["bs"]),
        ("Bulgarian", ["bg"]),
        ("Catalan", ["ca"]),
        ("Croatian", ["hr"]),
        ("Czech", ["cs"]),
        ("Danish", ["da", "da-DK"]),
        ("Dutch", ["nl"]),
        ("English", ["en", "en-US", "en-AU", "en-GB", "en-IN", "en-NZ"]),
        ("Estonian", ["et"]),
        ("Finnish", ["fi"]),
        ("Flemish", ["nl-BE"]),
        ("French", ["fr", "fr-CA"]),
        ("German", ["de"]),
        ("German (Switzerland)", ["de-CH"]),
        ("Greek", ["el"]),
        ("Hebrew", ["he"]),
        ("Hindi", ["hi"]),
        ("Hungarian", ["hu"]),
        ("Indonesian", ["id"]),
        ("Italian", ["it"]),
        ("Japanese", ["ja"]),
        ("Kannada", ["kn"]),
        ("Korean", ["ko", "ko-KR"]),
        ("Latvian", ["lv"]),
        ("Lithuanian", ["lt"]),
        ("Macedonian", ["mk"]),
        ("Malay", ["ms"]),
        ("Marathi", ["mr"]),
        ("Norwegian", ["no"]),
        ("Persian", ["fa"]),
        ("Polish", ["pl"]),
        ("Portuguese", ["pt", "pt-BR", "pt-PT"]),
        ("Romanian", ["ro"]),
        ("Russian", ["ru"]),
        ("Serbian", ["sr"]),
        ("Slovak", ["sk"]),
        ("Slovenian", ["sl"]),
        ("Spanish", ["es", "es-419"]),
        ("Swedish", ["sv", "sv-SE"]),
        ("Tagalog", ["tl"]),
        ("Tamil", ["ta"]),
        ("Telugu", ["te"]),
        ("Turkish", ["tr"]),
        ("Ukrainian", ["uk"]),
        ("Urdu", ["ur"]),
        ("Vietnamese", ["vi"]),
    ]

    nonisolated private static let deepgramNova2LanguageGroups: [(String, [String])] = [
        ("Bulgarian", ["bg"]),
        ("Catalan", ["ca"]),
        ("Chinese (Mandarin, Simplified)", ["zh", "zh-CN", "zh-Hans"]),
        ("Chinese (Mandarin, Traditional)", ["zh-TW", "zh-Hant"]),
        ("Chinese (Cantonese, Traditional)", ["zh-HK"]),
        ("Czech", ["cs"]),
        ("Danish", ["da", "da-DK"]),
        ("Dutch", ["nl"]),
        ("English", ["en", "en-US", "en-AU", "en-GB", "en-NZ", "en-IN"]),
        ("Estonian", ["et"]),
        ("Finnish", ["fi"]),
        ("Flemish", ["nl-BE"]),
        ("French", ["fr", "fr-CA"]),
        ("German", ["de"]),
        ("German (Switzerland)", ["de-CH"]),
        ("Greek", ["el"]),
        ("Hindi", ["hi"]),
        ("Hungarian", ["hu"]),
        ("Indonesian", ["id"]),
        ("Italian", ["it"]),
        ("Japanese", ["ja"]),
        ("Korean", ["ko", "ko-KR"]),
        ("Latvian", ["lv"]),
        ("Lithuanian", ["lt"]),
        ("Malay", ["ms"]),
        ("Norwegian", ["no"]),
        ("Polish", ["pl"]),
        ("Portuguese", ["pt", "pt-BR", "pt-PT"]),
        ("Romanian", ["ro"]),
        ("Russian", ["ru"]),
        ("Slovak", ["sk"]),
        ("Spanish", ["es", "es-419"]),
        ("Swedish", ["sv", "sv-SE"]),
        ("Thai", ["th", "th-TH"]),
        ("Turkish", ["tr"]),
        ("Ukrainian", ["uk"]),
        ("Vietnamese", ["vi"]),
    ]

    nonisolated private static let elevenLabsLanguageGroups: [(String, [String])] = [
        ("Afrikaans", ["afr"]),
        ("Amharic", ["amh"]),
        ("Arabic", ["ara"]),
        ("Armenian", ["hye"]),
        ("Assamese", ["asm"]),
        ("Asturian", ["ast"]),
        ("Azerbaijani", ["aze"]),
        ("Belarusian", ["bel"]),
        ("Bengali", ["ben"]),
        ("Bosnian", ["bos"]),
        ("Bulgarian", ["bul"]),
        ("Burmese", ["mya"]),
        ("Cantonese", ["yue"]),
        ("Catalan", ["cat"]),
        ("Cebuano", ["ceb"]),
        ("Chichewa", ["nya"]),
        ("Croatian", ["hrv"]),
        ("Czech", ["ces"]),
        ("Danish", ["dan"]),
        ("Dutch", ["nld"]),
        ("English", ["eng"]),
        ("Estonian", ["est"]),
        ("Filipino", ["fil"]),
        ("Finnish", ["fin"]),
        ("French", ["fra"]),
        ("Fulah", ["ful"]),
        ("Galician", ["glg"]),
        ("Ganda", ["lug"]),
        ("Georgian", ["kat"]),
        ("German", ["deu"]),
        ("Greek", ["ell"]),
        ("Gujarati", ["guj"]),
        ("Hausa", ["hau"]),
        ("Hebrew", ["heb"]),
        ("Hindi", ["hin"]),
        ("Hungarian", ["hun"]),
        ("Icelandic", ["isl"]),
        ("Igbo", ["ibo"]),
        ("Indonesian", ["ind"]),
        ("Irish", ["gle"]),
        ("Italian", ["ita"]),
        ("Japanese", ["jpn"]),
        ("Javanese", ["jav"]),
        ("Kabuverdianu", ["kea"]),
        ("Kannada", ["kan"]),
        ("Kazakh", ["kaz"]),
        ("Khmer", ["khm"]),
        ("Korean", ["kor"]),
        ("Kurdish", ["kur"]),
        ("Kyrgyz", ["kir"]),
        ("Lao", ["lao"]),
        ("Latvian", ["lav"]),
        ("Lingala", ["lin"]),
        ("Lithuanian", ["lit"]),
        ("Luo", ["luo"]),
        ("Luxembourgish", ["ltz"]),
        ("Macedonian", ["mkd"]),
        ("Malay", ["msa"]),
        ("Malayalam", ["mal"]),
        ("Maltese", ["mlt"]),
        ("Mandarin Chinese", ["zho"]),
        ("Maori", ["mri"]),
        ("Marathi", ["mar"]),
        ("Mongolian", ["mon"]),
        ("Nepali", ["nep"]),
        ("Northern Sotho", ["nso"]),
        ("Norwegian", ["nor"]),
        ("Occitan", ["oci"]),
        ("Odia", ["ori"]),
        ("Pashto", ["pus"]),
        ("Persian", ["fas"]),
        ("Polish", ["pol"]),
        ("Portuguese", ["por"]),
        ("Punjabi", ["pan"]),
        ("Romanian", ["ron"]),
        ("Russian", ["rus"]),
        ("Serbian", ["srp"]),
        ("Shona", ["sna"]),
        ("Sindhi", ["snd"]),
        ("Slovak", ["slk"]),
        ("Slovenian", ["slv"]),
        ("Somali", ["som"]),
        ("Spanish", ["spa"]),
        ("Swahili", ["swa"]),
        ("Swedish", ["swe"]),
        ("Tamil", ["tam"]),
        ("Tajik", ["tgk"]),
        ("Telugu", ["tel"]),
        ("Thai", ["tha"]),
        ("Turkish", ["tur"]),
        ("Ukrainian", ["ukr"]),
        ("Umbundu", ["umb"]),
        ("Urdu", ["urd"]),
        ("Uzbek", ["uzb"]),
        ("Vietnamese", ["vie"]),
        ("Welsh", ["cym"]),
        ("Wolof", ["wol"]),
        ("Xhosa", ["xho"]),
        ("Zulu", ["zul"]),
    ]
}

/// Protocol that all transcription providers must implement
protocol TranscriptionProvider {
    /// Unique identifier for this provider
    var providerType: TranscriptionProviderType { get }
    
    /// Transcribe audio data to text
    /// - Parameters:
    ///   - audioData: The audio data to transcribe
    ///   - fileName: Optional filename for the audio (used in multipart forms)
    /// - Returns: The transcribed text
    /// - Throws: TranscriptionError if transcription fails
    func transcribe(audioData: Data, fileName: String) async throws -> String
    
    /// Check if the provider is properly configured (has valid API key, etc.)
    var isConfigured: Bool { get }
}

/// Unified error type for all transcription providers
enum TranscriptionError: Error, LocalizedError {
    case missingAPIKey(provider: String)
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case emptyTranscription
    case networkError(Error)
    case decodingError(Error)
    case providerNotConfigured
    /// The request did not complete within the configured timeout interval.
    case timeout(provider: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "\(provider) API key not configured"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        case .emptyTranscription:
            return "Transcription returned empty text"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .providerNotConfigured:
            return "Transcription provider not properly configured"
        case .timeout(let provider):
            return "\(provider) did not respond in time"
        }
    }

    /// Returns true for errors where retrying with a different provider is worthwhile.
    var shouldTryFallback: Bool {
        switch self {
        case .timeout: return true
        case .apiError(let statusCode, _): return statusCode == 429 || statusCode >= 500
        case .networkError: return true
        case .missingAPIKey: return false
        case .emptyTranscription: return false
        case .invalidURL, .invalidResponse, .decodingError, .providerNotConfigured: return false
        }
    }
}
