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
            // AfterFirstUnlock: accessible after the user logs in once per boot,
            // without prompting for the system password on every app launch.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
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
            kSecAttrService as String: "openwispher_api_keys"
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

    
    /// Re-write any existing keychain items to use the AfterFirstUnlock accessibility level.
    /// Run once on launch to silently upgrade keys stored under the old WhenUnlocked attribute,
    /// which caused a system-password prompt on every fresh app launch.
    internal static func migrateKeychainAccessibility() {
        let migrationKey = "com.openwispher.keychainAccessibilityMigrated.v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let providers: [TranscriptionProviderType] = [.groq, .elevenLabs, .deepgram]
        var allSucceeded = true
        for provider in providers {
            // Read the existing value (if any) — this may still prompt once
            // during this single migration run, but never again afterwards.
            guard let existingKey = retrieveAPIKey(for: provider), !existingKey.isEmpty else { continue }
            // Re-store with the new accessibility attribute (delete-then-add inside storeAPIKey)
            do {
                try storeAPIKey(existingKey, for: provider)
            } catch {
                print("⚠️ SecureStorage: failed to migrate keychain accessibility for \(provider.rawValue): \(error)")
                allSucceeded = false
            }
        }

        // Only mark migration complete if every present key was successfully re-written.
        if allSucceeded {
            UserDefaults.standard.set(true, forKey: migrationKey)
        }
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

    }
    
    /// Clear all stored API keys
    internal static func clearAllAPIKeys() {
        let providers: [TranscriptionProviderType] = [.groq, .elevenLabs, .deepgram]
        
        for provider in providers {
            try? deleteAPIKey(for: provider)
        }

        // Also clear from UserDefaults as fallback
        UserDefaults.standard.removeObject(forKey: "groqAPIKey")
        UserDefaults.standard.removeObject(forKey: "elevenLabsAPIKey")
        UserDefaults.standard.removeObject(forKey: "deepgramAPIKey")
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
