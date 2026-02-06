//
//  UpdateManager.swift
//  dhavnii
//
//  Lightweight updater for unsigned web distribution.
//

import Foundation
import AppKit
import CryptoKit
import OSLog

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
    internal private(set) var expectedSHA256: String?
    internal private(set) var statusText = "Not checked yet"
    internal private(set) var lastCheckedAt: Date?
    private var latestManifest: ReleaseManifest?

    private static let manifestURL = URL(string: "https://github.com/maker-or/dhavnii/releases/latest/download/latest.json")
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "dhavnii", category: "UpdateManager")

    internal func checkForUpdates() async {
        guard !isChecking else { return }
        guard let manifestURL = Self.manifestURL else {
            statusText = "Update URL is not configured"
            return
        }

        updateAvailable = false
        downloadURL = nil
        notesURL = nil
        latestVersion = nil
        expectedSHA256 = nil
        latestManifest = nil
        statusText = "Checking for updates..."

        isChecking = true
        defer {
            isChecking = false
            lastCheckedAt = Date()
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: manifestURL)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                updateAvailable = false
                downloadURL = nil
                notesURL = nil
                latestVersion = nil
                expectedSHA256 = nil
                latestManifest = nil
                statusText = "Unable to reach update server"
                return
            }

            let manifest = try JSONDecoder().decode(ReleaseManifest.self, from: data)
            latestManifest = manifest
            latestVersion = manifest.version
            downloadURL = manifest.dmgURL
            notesURL = manifest.notesURL
            expectedSHA256 = manifest.sha256

            let hasUpdate = Self.isVersion(manifest.version, newerThan: currentVersion)
            updateAvailable = hasUpdate
            statusText = hasUpdate ? "Update available: v\(manifest.version)" : "You're up to date (v\(currentVersion))"
        } catch {
            updateAvailable = false
            downloadURL = nil
            notesURL = nil
            latestVersion = nil
            expectedSHA256 = nil
            latestManifest = nil
            statusText = "Update check failed"
            Self.logger.error("Update check failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    internal func openDownloadURL() {
        Task {
            await downloadAndOpenVerifiedDMG()
        }
    }

    internal func openReleaseNotes() {
        guard let notesURL else { return }
        NSWorkspace.shared.open(notesURL)
    }

    private static var installedVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private func downloadAndOpenVerifiedDMG() async {
        guard let manifest = latestManifest, updateAvailable else {
            statusText = "No update available"
            return
        }

        statusText = "Downloading update..."

        do {
            let (temporaryURL, response) = try await URLSession.shared.download(from: manifest.dmgURL)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                statusText = "Update download failed"
                Self.logger.error("Update download failed with non-2xx response")
                return
            }

            let computedSHA256 = try Self.streamedSHA256Hex(for: temporaryURL)
            let expectedSHA256 = manifest.sha256.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            guard computedSHA256 == expectedSHA256 else {
                try? FileManager.default.removeItem(at: temporaryURL)
                statusText = "Update verification failed"
                Self.logger.error(
                    "SHA mismatch. expected=\(expectedSHA256, privacy: .public) actual=\(computedSHA256, privacy: .public)"
                )
                return
            }

            let finalURL = try Self.persistDownloadedDMG(from: temporaryURL, sourceURL: manifest.dmgURL)
            statusText = "Verified update ready"
            NSWorkspace.shared.open(finalURL)
        } catch {
            statusText = "Update download failed"
            Self.logger.error("Update download failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        let normalizedLeft = normalizedVersion(lhs)
        let normalizedRight = normalizedVersion(rhs)
        let left = numericSegments(from: normalizedLeft, original: lhs)
        let right = numericSegments(from: normalizedRight, original: rhs)
        let count = max(left.count, right.count)

        for index in 0..<count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l > r }
        }
        return false
    }

    private static func normalizedVersion(_ version: String) -> String {
        var value = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("v") || value.hasPrefix("V") {
            value.removeFirst()
        }
        return value
    }

    private static func numericSegments(from normalizedVersion: String, original: String) -> [Int] {
        normalizedVersion.split(separator: ".").map { segment in
            if let value = Int(segment) {
                return value
            }

            logger.warning(
                "Non-numeric version segment '\(String(segment), privacy: .public)' in '\(original, privacy: .public)'; treating as 0"
            )
            return 0
        }
    }

    private static func streamedSHA256Hex(for fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { handle.closeFile() }

        var hasher = SHA256()
        let chunkSize = 64 * 1024

        while true {
            guard let data = try handle.read(upToCount: chunkSize), !data.isEmpty else {
                break
            }
            hasher.update(data: data)
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func persistDownloadedDMG(from temporaryURL: URL, sourceURL: URL) throws -> URL {
        let filename = sourceURL.lastPathComponent.isEmpty ? "Dhavnii-update.dmg" : sourceURL.lastPathComponent
        let finalURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: finalURL.path) {
            try FileManager.default.removeItem(at: finalURL)
        }

        try FileManager.default.moveItem(at: temporaryURL, to: finalURL)
        return finalURL
    }
}
