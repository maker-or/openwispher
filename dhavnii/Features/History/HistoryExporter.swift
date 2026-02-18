//
//  HistoryExporter.swift
//  OpenWispher
//
//  Exports transcription history to a plain text file via NSSavePanel.
//

import AppKit
import Foundation
internal import UniformTypeIdentifiers

/// Handles exporting transcription records to a plain text file.
@MainActor
enum HistoryExporter {

    /// Convenience wrapper: formats, presents the save panel, writes the file,
    /// and — on success — fires `AnalyticsManager.shared.trackHistoryExported`.
    /// Returns `true` if the file was written successfully.
    @discardableResult
    static func exportAndTrack(_ records: [TranscriptionRecord]) -> Bool {
        let exported = exportAsText(records)
        if exported {
            AnalyticsManager.shared.trackHistoryExported(count: records.count)
        }
        return exported
    }

    /// Formats `records` as plain text and presents a save panel to the user.
    /// Returns `true` if the file was written successfully.
    @discardableResult
    static func exportAsText(_ records: [TranscriptionRecord]) -> Bool {
        guard !records.isEmpty else { return false }

        let content = formatted(records)

        let panel = NSSavePanel()
        panel.title = "Export Transcriptions"
        panel.nameFieldStringValue = defaultFilename()
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return false }

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("❌ HistoryExporter: failed to write file: \(error)")
            return false
        }
    }

    // MARK: - Private helpers

    private static func formatted(_ records: [TranscriptionRecord]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        let header = """
            OpenWispher — Transcription History
            Exported: \(dateFormatter.string(from: Date()))
            Total: \(records.count) transcription\(records.count == 1 ? "" : "s")
            ════════════════════════════════════════

            """

        let blocks = records.map { record -> String in
            var lines: [String] = []
            lines.append(dateFormatter.string(from: record.timestamp))
            lines.append("Provider: \(record.provider)")
            if let duration = record.audioDuration {
                lines.append("Duration: \(formattedDuration(duration))")
            }
            if record.isFavorite {
                lines.append("Starred")
            }
            lines.append("")
            lines.append(record.text)
            return lines.joined(separator: "\n")
        }

        return header + blocks.joined(separator: "\n\n────────────────────────────────────────\n\n") + "\n"
    }

    private static func defaultFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "transcriptions-\(formatter.string(from: Date())).txt"
    }

    private static func formattedDuration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let m = total / 60
        let s = total % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }
}
