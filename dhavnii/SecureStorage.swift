//
//  SecureStorage.swift
//  OpenWispher
//
//  Secure keychain-based storage for API keys and sensitive data.
//

import Foundation
import Security

/// Secure storage manager using macOS Keychain Services
internal enum SecureStorage {
    // MARK: - In-memory Cache
    private static var cachedKeys: [String: String] = [:]
    private static let cacheLock = NSLock()
    
    // MARK: - Keychain Keys
    private static let groqAPIKey = "com.openwispher.apiKeys.groq"
    private static let elevenLabsAPIKey = "com.openwispher.apiKeys.elevenlabs"
    private static let deepgramAPIKey = "com.openwispher.apiKeys.deepgram"
    private static let openAIAPIKey = "com.openwispher.apiKeys.openai"
    
    // MARK: - Error Types
    internal enum KeychainError: Error {
        case itemNotFound
        case duplicateItem
        case invalidStatus(OSStatus)
        case conversionFailed
    }
    
    // MARK: - Public Methods
    
    /// Store an API key for a specific provider
    internal static func storeAPIKey(_ apiKey: String, for provider: TranscriptionProviderType) throws {
        let key = keychainKey(for: provider)
        
        // Delete any existing item first
        try? deleteAPIKey(for: provider)
        
        guard let data = apiKey.data(using: .utf8) else {
            throw KeychainError.conversionFailed
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "openwispher_api_keys",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.invalidStatus(status)
        }

        cacheLock.lock()
        cachedKeys[key] = apiKey
        cacheLock.unlock()
    }
    
    /// Retrieve an API key for a specific provider
    internal static func retrieveAPIKey(for provider: TranscriptionProviderType) -> String? {
        let key = keychainKey(for: provider)

        cacheLock.lock()
        if let cached = cachedKeys[key], !cached.isEmpty {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "openwispher_api_keys",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        cacheLock.lock()
        cachedKeys[key] = apiKey
        cacheLock.unlock()
        return apiKey
    }
    
    /// Delete an API key for a specific provider
    internal static func deleteAPIKey(for provider: TranscriptionProviderType) throws {
        let key = keychainKey(for: provider)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "dhavnii_api_keys"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.invalidStatus(status)
        }

        cacheLock.lock()
        cachedKeys[key] = ""
        cacheLock.unlock()
    }
    
    /// Check if an API key exists for a provider
    internal static func hasAPIKey(for provider: TranscriptionProviderType) -> Bool {
        return retrieveAPIKey(for: provider) != nil
    }

    // MARK: - TTS API Keys

    internal static func storeTTSAPIKey(_ apiKey: String, for provider: TTSProviderType) throws {
        if let sharedProvider = transcriptionProvider(for: provider) {
            try storeAPIKey(apiKey, for: sharedProvider)
            return
        }
        let key = keychainKey(forTTS: provider)
        try? deleteTTSAPIKey(for: provider)
        guard let data = apiKey.data(using: .utf8) else {
            throw KeychainError.conversionFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "openwispher_api_keys",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.invalidStatus(status)
        }

        cacheLock.lock()
        cachedKeys[key] = apiKey
        cacheLock.unlock()
    }

    internal static func retrieveTTSAPIKey(for provider: TTSProviderType) -> String? {
        if let sharedProvider = transcriptionProvider(for: provider) {
            return retrieveAPIKey(for: sharedProvider)
        }
        let key = keychainKey(forTTS: provider)

        cacheLock.lock()
        if let cached = cachedKeys[key], !cached.isEmpty {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "openwispher_api_keys",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            return nil
        }

        cacheLock.lock()
        cachedKeys[key] = apiKey
        cacheLock.unlock()
        return apiKey
    }

    internal static func deleteTTSAPIKey(for provider: TTSProviderType) throws {
        if let sharedProvider = transcriptionProvider(for: provider) {
            try deleteAPIKey(for: sharedProvider)
            return
        }
        let key = keychainKey(forTTS: provider)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "dhavnii_api_keys"
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.invalidStatus(status)
        }

        cacheLock.lock()
        cachedKeys[key] = ""
        cacheLock.unlock()
    }

    internal static func hasTTSAPIKey(for provider: TTSProviderType) -> Bool {
        return retrieveTTSAPIKey(for: provider) != nil
    }
    
    /// Migrate existing UserDefaults keys to Keychain (one-time migration)
    internal static func migrateFromUserDefaults() {
        let providers: [TranscriptionProviderType] = [.groq, .elevenLabs, .deepgram]
        
        for provider in providers {
            let userDefaultsKey: String
            switch provider {
            case .groq:
                userDefaultsKey = "groqAPIKey"
            case .elevenLabs:
                userDefaultsKey = "elevenLabsAPIKey"
            case .deepgram:
                userDefaultsKey = "deepgramAPIKey"
            }
            
            // Check if already in keychain
            guard retrieveAPIKey(for: provider) == nil else { continue }
            
            // Migrate from UserDefaults if exists
            if let apiKey = UserDefaults.standard.string(forKey: userDefaultsKey),
               !apiKey.isEmpty {
                do {
                    try storeAPIKey(apiKey, for: provider)
                    // Clear from UserDefaults after successful migration
                    UserDefaults.standard.removeObject(forKey: userDefaultsKey)
                    print("✅ Migrated \(provider.rawValue) API key to Keychain")
                } catch {
                    print("❌ Failed to migrate \(provider.rawValue) API key: \(error)")
                }
            }
        }

        // Migrate OpenAI TTS key if present
        let openAIKey = UserDefaults.standard.string(forKey: "openAIAPIKey") ?? ""
        if !openAIKey.isEmpty, retrieveTTSAPIKey(for: .openAI) == nil {
            do {
                try storeTTSAPIKey(openAIKey, for: .openAI)
                UserDefaults.standard.removeObject(forKey: "openAIAPIKey")
                print("✅ Migrated OpenAI API key to Keychain")
            } catch {
                print("❌ Failed to migrate OpenAI API key: \(error)")
            }
        }
    }
    
    /// Clear all stored API keys
    internal static func clearAllAPIKeys() {
        let providers: [TranscriptionProviderType] = [.groq, .elevenLabs, .deepgram]
        
        for provider in providers {
            try? deleteAPIKey(for: provider)
        }

        let ttsProviders: [TTSProviderType] = [.openAI]
        for provider in ttsProviders {
            try? deleteTTSAPIKey(for: provider)
        }
        
        // Also clear from UserDefaults as fallback
        UserDefaults.standard.removeObject(forKey: "groqAPIKey")
        UserDefaults.standard.removeObject(forKey: "elevenLabsAPIKey")
        UserDefaults.standard.removeObject(forKey: "deepgramAPIKey")
        UserDefaults.standard.removeObject(forKey: "openAIAPIKey")
    }
    
    // MARK: - Private Helpers
    
    private static func keychainKey(for provider: TranscriptionProviderType) -> String {
        switch provider {
        case .groq:
            return groqAPIKey
        case .elevenLabs:
            return elevenLabsAPIKey
        case .deepgram:
            return deepgramAPIKey
        }
    }

    private static func keychainKey(forTTS provider: TTSProviderType) -> String {
        switch provider {
        case .groq:
            return groqAPIKey
        case .deepgram:
            return deepgramAPIKey
        case .elevenLabs:
            return elevenLabsAPIKey
        case .openAI:
            return openAIAPIKey
        }
    }

    private static func transcriptionProvider(for provider: TTSProviderType) -> TranscriptionProviderType? {
        switch provider {
        case .groq:
            return .groq
        case .deepgram:
            return .deepgram
        case .elevenLabs:
            return .elevenLabs
        case .openAI:
            return nil
        }
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

/// Property wrapper for easy API key binding in SwiftUI
@propertyWrapper
internal struct SecureAPIKey: DynamicProperty {
    private let provider: TranscriptionProviderType
    
    init(_ provider: TranscriptionProviderType) {
        self.provider = provider
    }
    
    var wrappedValue: String {
        get {
            SecureStorage.retrieveAPIKey(for: provider) ?? ""
        }
        nonmutating set {
            if newValue.isEmpty {
                try? SecureStorage.deleteAPIKey(for: provider)
            } else {
                try? SecureStorage.storeAPIKey(newValue, for: provider)
            }
        }
    }
    
    var projectedValue: Binding<String> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
}

@propertyWrapper
internal struct SecureTTSAPIKey: DynamicProperty {
    private let provider: TTSProviderType

    init(_ provider: TTSProviderType) {
        self.provider = provider
    }

    var wrappedValue: String {
        get {
            SecureStorage.retrieveTTSAPIKey(for: provider) ?? ""
        }
        nonmutating set {
            if newValue.isEmpty {
                try? SecureStorage.deleteTTSAPIKey(for: provider)
            } else {
                try? SecureStorage.storeTTSAPIKey(newValue, for: provider)
            }
        }
    }

    var projectedValue: Binding<String> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
}
