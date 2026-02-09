//
//  AnalyticsManager.swift
//  Openwispher
//
//  Minimal PostHog analytics for app opens and hotkey presses.
//

import Foundation
import PostHog

@MainActor
internal final class AnalyticsManager {
    internal static let shared = AnalyticsManager()

    private var isConfigured = false

    private init() {}

    @discardableResult
    internal func configureIfNeeded() -> Bool {
        guard !isConfigured else { return true }

        let apiKey = resolvedInfoValue(primaryKey: "POSTHOG_API_KEY", fallbackKey: "INFOPLIST_KEY_POSTHOG_API_KEY")
            ?? ProcessInfo.processInfo.environment["POSTHOG_API_KEY"]
        guard let apiKey, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            #if DEBUG
            print("⚠️ PostHog API key missing. Analytics disabled.")
            #endif
            return false
        }

        let rawHost = resolvedInfoValue(primaryKey: "POSTHOG_HOST", fallbackKey: "INFOPLIST_KEY_POSTHOG_HOST")
            ?? ProcessInfo.processInfo.environment["POSTHOG_HOST"]
        let host = rawHost?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedHost = (host?.isEmpty == false) ? host! : "https://us.i.posthog.com"

        #if DEBUG
        let apiKeyPrefix = apiKey.prefix(6)
        print("🔎 PostHog config: host=\(resolvedHost), apiKey=\(apiKeyPrefix)...")
        #endif

        let config = PostHogConfig(apiKey: apiKey, host: resolvedHost)
        config.personProfiles = .never
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false

        #if DEBUG
        config.debug = true
        config.flushAt = 1
        #endif

        PostHogSDK.shared.setup(config)
        registerAppMetadata()
        isConfigured = true
        return true
    }

    internal func trackAppOpened() {
        guard configureIfNeeded() else {
            #if DEBUG
            print("⚠️ PostHog not configured. Skipping app_opened.")
            #endif
            return
        }
        PostHogSDK.shared.capture("app_opened")

        #if DEBUG
        PostHogSDK.shared.flush()
        #endif
    }

    internal func trackHotkeyPressed(hotkey: HotkeyDefinition) {
        guard configureIfNeeded() else {
            #if DEBUG
            print("⚠️ PostHog not configured. Skipping hotkey_pressed.")
            #endif
            return
        }
        PostHogSDK.shared.capture(
            "hotkey_pressed",
            properties: [
                "hotkey_key_code": Int(hotkey.keyCode),
                "hotkey_modifiers": Int(hotkey.modifiers),
                "hotkey_display": hotkey.displayString,
            ]
        )

        #if DEBUG
        PostHogSDK.shared.flush()
        #endif
    }

    private func registerAppMetadata() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        var properties: [String: Any] = [:]
        if let version, !version.isEmpty {
            properties["app_version"] = version
        }
        if let build, !build.isEmpty {
            properties["app_build"] = build
        }

        guard !properties.isEmpty else { return }
        PostHogSDK.shared.register(properties)
    }

    private func resolvedInfoValue(primaryKey: String, fallbackKey: String) -> String? {
        if let value = Bundle.main.object(forInfoDictionaryKey: primaryKey) as? String, !value.isEmpty {
            return value
        }
        if let value = Bundle.main.object(forInfoDictionaryKey: fallbackKey) as? String, !value.isEmpty {
            return value
        }
        return nil
    }
}
