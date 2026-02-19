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
    private var appOpenedCount = 0

    private init() {}

    @discardableResult
    internal func configureIfNeeded() -> Bool {
        guard !isConfigured else {
            #if DEBUG
            print("📊 PostHog already configured")
            #endif
            return true
        }

        #if DEBUG
        print("📊 Configuring PostHog SDK")
        #endif

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
        config.flushAt = 1

        #if DEBUG
        config.debug = true
        #endif

        PostHogSDK.shared.setup(config)
        registerAppMetadata()
        isConfigured = true

        #if DEBUG
        print("✅ PostHog SDK configured")
        #endif

        return true
    }

    internal func trackAppOpened(trigger: String = "unknown") {
        #if DEBUG
        print("🚀 trackAppOpened called (trigger=\(trigger))")
        #endif

        guard configureIfNeeded() else {
            #if DEBUG
            print("⚠️ PostHog not configured. Skipping app_opened.")
            #endif
            return
        }

        appOpenedCount += 1
        captureAndFlush(
            "app_opened",
            properties: [
                "trigger": trigger,
                "open_count_in_run": appOpenedCount,
            ]
        )
    }

    internal func trackHotkeyPressed(hotkey: HotkeyDefinition) {
        guard configureIfNeeded() else {
            #if DEBUG
            print("⚠️ PostHog not configured. Skipping hotkey_pressed.")
            #endif
            return
        }
        captureAndFlush(
            "hotkey_pressed",
            properties: [
                "hotkey_key_code": Int(hotkey.keyCode),
                "hotkey_modifiers": Int(hotkey.modifiers),
                "hotkey_display": hotkey.displayString,
            ]
        )
    }

    internal func trackOnboardingStepViewed(step: String) {
        guard configureIfNeeded() else { return }
        captureAndFlush(
            "onboarding_\(step)_viewed",
            properties: ["step": step]
        )
    }

    internal func trackOnboardingCompleted() {
        guard configureIfNeeded() else { return }
        captureAndFlush("onboarding_completed")
    }

    internal func trackHistoryExported(count: Int) {
        guard configureIfNeeded() else { return }
        captureAndFlush(
            "history_exported",
            properties: ["transcription_count": count]
        )
    }

    internal func trackFallbackUsed(
        primary: TranscriptionProviderType,
        fallback: TranscriptionProviderType,
        reason: String
    ) {
        guard configureIfNeeded() else { return }
        captureAndFlush(
            "transcription_fallback_used",
            properties: [
                "primary_provider": primary.rawValue,
                "fallback_provider": fallback.rawValue,
                "reason": reason,
            ]
        )
    }

    private func captureAndFlush(_ event: String, properties: [String: Any]? = nil) {
        #if DEBUG
        if let properties {
            print("📊 Capturing event '\(event)' with properties: \(properties)")
        } else {
            print("📊 Capturing event '\(event)'")
        }
        #endif

        if let properties {
            PostHogSDK.shared.capture(event, properties: properties)
        } else {
            PostHogSDK.shared.capture(event)
        }
        PostHogSDK.shared.flush()
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
