//
//  AppState.swift
//  OpenWispher
//
//  Application state management for OpenWispher.
//

import Foundation
import SwiftUI

/// Represents the current state of the application
internal enum RecordingState: Equatable {
    case idle
    case recording
    case processing
    case success
    case error(message: String)
}

/// Observable application state
@MainActor
@Observable
internal class AppState {
    internal var recordingState: RecordingState = .idle
    internal var lastTranscription: String = ""
    internal var hasMicrophonePermission: Bool = false
    internal var hasAccessibilityPermission: Bool = false
    internal var hasCompletedOnboarding: Bool = false

    /// Check if all required permissions are granted
    internal var hasAllPermissions: Bool {
        hasMicrophonePermission && hasAccessibilityPermission
    }
}
