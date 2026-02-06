//
//  UpdateManager.swift
//  dhavnii
//
//  Lightweight updater for unsigned web distribution.
//

import Foundation
import AppKit

@MainActor
@Observable
internal final class UpdateManager {
    internal struct ReleaseManifest: Decodable {
        let version: String
        let dmgURL: URL
        let notesURL: URL
        let sha256: String
        let publishedAt: String

        enum CodingKeys: String, CodingKey {
            case version
            case dmgURL = "dmg_url"
            case notesURL = "notes_url"
            case sha256
            case publishedAt = "published_at"
        }
    }

    internal private(set) var isChecking = false
    internal private(set) var currentVersion: String = UpdateManager.installedVersion
    internal private(set) var latestVersion: String?
    internal private(set) var updateAvailable = false
    internal private(set) var downloadURL: URL?
    internal private(set) var notesURL: URL?
    internal private(set) var statusText = "Not checked yet"
    internal private(set) var lastCheckedAt: Date?

    private static let manifestURL = URL(string: "https://github.com/maker-or/dhavnii/releases/latest/download/latest.json")

    internal func checkForUpdates() async {
        guard !isChecking else { return }
        guard let manifestURL = Self.manifestURL else {
            statusText = "Update URL is not configured"
            return
        }

        isChecking = true
        defer {
            isChecking = false
            lastCheckedAt = Date()
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: manifestURL)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                statusText = "Unable to reach update server"
                return
            }

            let manifest = try JSONDecoder().decode(ReleaseManifest.self, from: data)
            latestVersion = manifest.version
            downloadURL = manifest.dmgURL
            notesURL = manifest.notesURL

            let hasUpdate = Self.isVersion(manifest.version, newerThan: currentVersion)
            updateAvailable = hasUpdate
            statusText = hasUpdate ? "Update available: v\(manifest.version)" : "You're up to date (v\(currentVersion))"
        } catch {
            statusText = "Update check failed"
            print("❌ Update check failed: \(error)")
        }
    }

    internal func openDownloadURL() {
        guard let downloadURL else { return }
        NSWorkspace.shared.open(downloadURL)
    }

    internal func openReleaseNotes() {
        guard let notesURL else { return }
        NSWorkspace.shared.open(notesURL)
    }

    private static var installedVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private static func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(left.count, right.count)

        for index in 0..<count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l > r }
        }
        return false
    }
}
