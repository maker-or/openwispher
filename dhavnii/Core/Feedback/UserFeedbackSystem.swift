//
//  UserFeedbackSystem.swift
//  OpenWispher
//
//  Comprehensive error handling and user feedback system with toast notifications.
//

import SwiftUI

// MARK: - Feedback Types

internal enum FeedbackType {
    case success
    case error
    case warning
    case info

    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

// MARK: - Feedback Message

internal struct FeedbackMessage: Identifiable, Equatable {
    let id = UUID()
    let type: FeedbackType
    let title: String
    let message: String?
    let duration: TimeInterval
    let action: FeedbackAction?

    init(
        type: FeedbackType,
        title: String,
        message: String? = nil,
        duration: TimeInterval = 3.0,
        action: FeedbackAction? = nil
    ) {
        self.type = type
        self.title = title
        self.message = message
        self.duration = duration
        self.action = action
    }

    static func == (lhs: FeedbackMessage, rhs: FeedbackMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Feedback Action

internal struct FeedbackAction {
    let title: String
    let handler: () -> Void
}

// MARK: - Feedback Manager

@Observable
internal class FeedbackManager {
    internal static let shared = FeedbackManager()

    internal var currentMessage: FeedbackMessage?
    internal var messageQueue: [FeedbackMessage] = []

    private var dismissTimer: Timer?

    private init() {
    }

    // MARK: - Show Feedback

    internal func show(_ message: FeedbackMessage) {
        DispatchQueue.main.async {
            if self.currentMessage != nil {
                // Queue the message if one is already showing
                self.messageQueue.append(message)
            } else {
                self.displayMessage(message)
            }
        }
    }

    internal func success(_ title: String, message: String? = nil, duration: TimeInterval = UIConstants.Toast.successDuration) {
        show(FeedbackMessage(type: .success, title: title, message: message, duration: duration))
    }

    internal func error(
        _ title: String, message: String? = nil, duration: TimeInterval = 4.0,
        action: FeedbackAction? = nil
    ) {
        show(
            FeedbackMessage(
                type: .error, title: title, message: message, duration: duration, action: action))
    }

    internal func warning(_ title: String, message: String? = nil, duration: TimeInterval = 3.5) {
        show(FeedbackMessage(type: .warning, title: title, message: message, duration: duration))
    }

    internal func info(_ title: String, message: String? = nil, duration: TimeInterval = 3.0) {
        show(FeedbackMessage(type: .info, title: title, message: message, duration: duration))
    }

    // MARK: - Specific Error Scenarios

    internal func showMicrophoneError() {
        error(
            "Microphone Access Required",
            message: "Please grant microphone permission in Settings",
            action: FeedbackAction(title: "Open Settings") {
                if let url = URL(
                    string:
                        "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
                ) {
                    NSWorkspace.shared.open(url)
                }
            }
        )
    }

    internal func showAccessibilityError() {
        error(
            "Accessibility Access Required",
            message: "Enable accessibility to use global hotkeys",
            action: FeedbackAction(title: "Open Settings") {
                if let url = URL(
                    string:
                        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                ) {
                    NSWorkspace.shared.open(url)
                }
            }
        )
    }

    internal func showNetworkError() {
        error(
            "Network Error",
            message: "Please check your internet connection",
            duration: 3.5
        )
    }

    internal func showAPIError(_ errorMessage: String? = nil) {
        error(
            "Transcription Failed",
            message: errorMessage ?? "Please try again",
            duration: 4.0
        )
    }

    internal func showRecordingError() {
        error(
            "Recording Failed",
            message: "Could not start audio recording",
            duration: 3.5
        )
    }

    internal func showTranscriptionSuccess() {
        success(
            "Copied to Clipboard",
            message: "Transcription ready to paste",
            duration: 2.0
        )
    }

    internal func showEmptyRecordingWarning() {
        warning(
            "No Audio Detected",
            message: "Please speak clearly and try again",
            duration: 3.0
        )
    }

    // MARK: - Display Management

    private func displayMessage(_ message: FeedbackMessage) {
        currentMessage = message

        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: message.duration, repeats: false) {
            [weak self] _ in
            self?.dismiss()
        }
    }

    private func showNextInQueue() {
        guard !messageQueue.isEmpty else { return }
        let nextMessage = messageQueue.removeFirst()
        displayMessage(nextMessage)
    }

    internal func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil

        withAnimation(SpringAnimation.smooth) {
            currentMessage = nil
        }
        
        // Show next message in queue after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.showNextInQueue()
        }
    }

    internal func clearAll() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        currentMessage = nil
        messageQueue.removeAll()
    }
}

// MARK: - Toast View

private struct ToastView: View {
    let message: FeedbackMessage
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: message.type.icon)
                .font(.title3)
                .foregroundColor(message.type.color)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(message.title)
                    .font(.subheadline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                if let messageText = message.message {
                    Text(messageText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Action button if provided
            if let action = message.action {
                Button(action: {
                    action.handler()
                    onDismiss()
                }) {
                    Text(action.title)
                        .font(.caption)
                        .font(.subheadline.weight(.medium))
                }
                .liquidGlassButtonStyle()
                .controlSize(.small)
            }

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .liquidGlassSurface(
            cornerRadius: 12,
            tint: message.type.color.opacity(0.08),
            fallbackFill: Color(nsColor: .controlBackgroundColor),
            strokeColor: message.type.color.opacity(0.3)
        )
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        .frame(maxWidth: UIConstants.Toast.maxWidth)
        .offset(y: isVisible ? 0 : -UIConstants.Toast.offset)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            withAnimation(SpringAnimation.smooth) {
                isVisible = true
            }
        }
    }
}

// MARK: - Toast Container

private struct ToastContainerView: View {
    var feedbackManager = FeedbackManager.shared

    var body: some View {
        VStack {
            if let message = feedbackManager.currentMessage {
                ToastView(message: message) {
                    feedbackManager.dismiss()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, UIConstants.Toast.padding)
                .padding(.horizontal, 16)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(feedbackManager.currentMessage != nil)
    }
}

// MARK: - View Modifier for Toast

private struct ToastModifier: ViewModifier {
    var feedbackManager = FeedbackManager.shared

    func body(content: Content) -> some View {
        ZStack {
            content

            ToastContainerView()
        }
    }
}

extension View {
    func withToasts() -> some View {
        modifier(ToastModifier())
    }
}

// MARK: - Error Extensions

internal extension Error {
    var userFriendlyMessage: String {
        if let transcriptionError = self as? TranscriptionError {
            switch transcriptionError {
            case .missingAPIKey(let provider):
                return "\(provider) API key not configured. Please check your settings."
            case .invalidURL:
                return "Invalid API configuration. Please check your settings."
            case .invalidResponse:
                return "Invalid response from server. Please try again."
            case .apiError(let statusCode, let message):
                return "Server error (\(statusCode)): \(message)"
            case .emptyTranscription:
                return "No speech detected. Please try again."
            case .networkError:
                return "Network error. Please check your connection."
            case .decodingError:
                return "Failed to parse response. Please try again."
            case .providerNotConfigured:
                return "Transcription provider not configured. Please check your settings."
            case .timeout(provider: let provider):
                return "\(provider) took too long to respond. Please try again."
            }
        }
        return localizedDescription
    }

    func showAsToast() {
        FeedbackManager.shared.error("Error", message: userFriendlyMessage)
    }
}

// MARK: - Permission Error Handling

internal extension PermissionManager {
    func showPermissionError(for permission: String) {
        switch permission.lowercased() {
        case "microphone":
            FeedbackManager.shared.showMicrophoneError()
        case "accessibility":
            FeedbackManager.shared.showAccessibilityError()
        default:
            FeedbackManager.shared.error(
                "Permission Required", message: "\(permission) permission is required")
        }
    }
}

// MARK: - Recording State Extensions

internal extension RecordingState {
    var feedbackMessage: FeedbackMessage? {
        switch self {
        case .success:
            return FeedbackMessage(type: .success, title: "Transcription Complete", duration: 2.0)
        case .error(let message):
            return FeedbackMessage(type: .error, title: "Error", message: message, duration: 3.5)
        default:
            return nil
        }
    }
}
