//
//  UIConstants.swift
//  OpenWispher
//
//  Centralized constants for UI dimensions, timing, and styling.
//

import Foundation

/// Centralized UI constants for consistent design
enum UIConstants {
    
    // MARK: - Window Sizes
    enum Window {
        static let mainWidth: CGFloat = 800  // Increased width for the new design
        static let mainHeight: CGFloat = 600 // Landscape orientation
        static let settingsWidth: CGFloat = 800 // Matching settings
        static let settingsHeight: CGFloat = 600
        static let onboardingWidth: CGFloat = 450
        static let onboardingHeight: CGFloat = 550
    }
    
    // MARK: - Notch Dimensions
    //
    // IMPORTANT:
    // We maintain TWO notch configurations:
    // - Speech-to-Text (STT): original sizing
    // - Text-to-Speech (TTS): larger sizing for better readability
    enum NotchSTT {
        static let pillWidth: CGFloat = 360
        static let pillHeight: CGFloat = 70
        static let topCornerRadius: CGFloat = 19
        static let bottomCornerRadius: CGFloat = 24
        static let windowWidth: CGFloat = 400
        static let windowHeight: CGFloat = 100
    }

    enum NotchTTS {
        static let pillWidth: CGFloat = 520
        static let pillHeight: CGFloat = 120
        static let topCornerRadius: CGFloat = 19
        static let bottomCornerRadius: CGFloat = 24
        static let windowWidth: CGFloat = 560
        static let windowHeight: CGFloat = 160
    }
    
    // MARK: - Spacing
    enum Spacing {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let standard: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 20
        static let section: CGFloat = 24
    }
    
    // MARK: - Corner Radius
    enum CornerRadius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 8
        static let standard: CGFloat = 10
        static let large: CGFloat = 12
        static let extraLarge: CGFloat = 16
    }
    
    // MARK: - Icon Sizes
    enum Icon {
        static let small: CGFloat = 16
        static let medium: CGFloat = 20
        static let standard: CGFloat = 40
        static let large: CGFloat = 50
        static let extraLarge: CGFloat = 60
        static let appIcon: CGFloat = 80
    }
    
    // MARK: - Animation Timing
    enum Animation {
        static let quick: TimeInterval = 0.2
        static let standard: TimeInterval = 0.3
        static let slow: TimeInterval = 0.5
        static let delay: TimeInterval = 0.01
        static let viewRemovalDelay: TimeInterval = 0.6
        static let heartbeatInterval: TimeInterval = 1.8
        static let rotationDuration: TimeInterval = 1.5
        static let pulseInterval: TimeInterval = 1.0
        static let shimmerDuration: TimeInterval = 1.5
    }
    
    // MARK: - Delays
    enum Delay {
        static let permissionCheck: TimeInterval = 0.5
        static let focusSettle: TimeInterval = 0.25
        static let stateReset: TimeInterval = 2.0
        static let successReset: TimeInterval = 1.5
        static let appActivation: TimeInterval = 0.2
        static let settingsReturn: TimeInterval = 0.3
        static let restartDelay: TimeInterval = 0.5
        static let restartCooldown: TimeInterval = 10.0
        static let debounce: TimeInterval = 0.5
    }
    
    // MARK: - Grid Layout (for icons)
    enum Grid {
        static let cellSize: CGFloat = 5.5
        static let gridSize: CGFloat = 16.5
        static let borderSize: CGFloat = 20
    }
    
    // MARK: - Toast
    enum Toast {
        static let maxWidth: CGFloat = 400
        static let defaultDuration: TimeInterval = 3.0
        static let successDuration: TimeInterval = 2.5
        static let errorDuration: TimeInterval = 4.0
        static let warningDuration: TimeInterval = 3.5
        static let infoDuration: TimeInterval = 3.0
        static let offset: CGFloat = 100
        static let padding: CGFloat = 16
    }
    
    // MARK: - Permission Monitoring
    enum Monitoring {
        static let backgroundInterval: TimeInterval = 3.0
        static let aggressiveInterval: TimeInterval = 0.5
        static let maxAggressiveDuration: TimeInterval = 90.0
        static let accessibilityCheckInterval: TimeInterval = 1.0
        static let stateChangeThreshold = 3
    }
}
