//
//  ClipboardManager.swift
//  OpenWispher
//
//  Clipboard and auto-paste functionality.
//

import Foundation
import AppKit
import Carbon

/// Manages clipboard operations and auto-pasting
class ClipboardManager {
    private let autoPasteRetryDelay: TimeInterval = 0.12
    private let autoPasteMaxAttempts = 10

    private struct FocusedElementState {
        let bundleIdentifier: String
        let role: String?
        let isEditable: Bool

        var isValidPasteTarget: Bool {
            switch role {
            case "AXTextField", "AXTextArea", "AXComboBox", "AXSearchField":
                return true
            case "AXWebArea", "AXGroup", "AXScrollArea":
                return isEditable
            default:
                return false
            }
        }
    }
    
    /// Copy text to the system clipboard
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    /// Check if a text input field is currently focused
    func isTextFieldFocused() -> Bool {
        focusedElementState()?.isValidPasteTarget ?? false
    }
    
    /// Simulate Cmd+V to paste
    func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Key down for Cmd+V
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // V key
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        
        // Key up for Cmd+V
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }
    
    /// Copy to clipboard and auto-paste if possible
    func copyAndPasteIfPossible(_ text: String) {
        // Always copy to clipboard (mandatory)
        copyToClipboard(text)

        let hasAccessibilityPermission = AXIsProcessTrusted()

        let frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown"
        print(
            "📋 Auto-paste decision: accessibility=\(hasAccessibilityPermission), frontmostApp=\(frontmostBundleIdentifier)"
        )

        guard hasAccessibilityPermission else {
            print("⚠️ Auto-paste skipped: accessibility permission unavailable")
            return
        }

        // Ensure OpenWispher is not the active app (stealing focus)
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier {
            NSApp.hide(nil)
        }

        // Wait for focus to return to a valid text target before posting Cmd+V.
        attemptPasteWhenReady(remainingAttempts: autoPasteMaxAttempts)
    }

    private func attemptPasteWhenReady(remainingAttempts: Int) {
        guard remainingAttempts > 0 else {
            let frontmostBundleIdentifier =
                NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown"
            let role = focusedElementState()?.role ?? "unknown"
            print(
                "⚠️ Auto-paste skipped: no editable target became ready, frontmostApp=\(frontmostBundleIdentifier), role=\(role)"
            )
            return
        }

        if let focusedElement = focusedElementState(),
           focusedElement.bundleIdentifier != Bundle.main.bundleIdentifier,
           focusedElement.isValidPasteTarget
        {
            print(
                "✅ Auto-paste target ready: frontmostApp=\(focusedElement.bundleIdentifier), role=\(focusedElement.role ?? "unknown"), editable=\(focusedElement.isEditable)"
            )
            simulatePaste()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + autoPasteRetryDelay) { [weak self] in
            self?.attemptPasteWhenReady(remainingAttempts: remainingAttempts - 1)
        }
    }

    private func focusedElementState() -> FocusedElementState? {
        guard let focusedApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(focusedApp.processIdentifier)

        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard result == .success, let element = focusedElement else {
            return FocusedElementState(
                bundleIdentifier: focusedApp.bundleIdentifier ?? "unknown",
                role: nil,
                isEditable: false
            )
        }

        let axElement = unsafeBitCast(element, to: AXUIElement.self)

        var roleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &roleValue)

        var editableValue: CFTypeRef?
        AXUIElementCopyAttributeValue(axElement, "AXEditable" as CFString, &editableValue)

        return FocusedElementState(
            bundleIdentifier: focusedApp.bundleIdentifier ?? "unknown",
            role: roleValue as? String,
            isEditable: editableValue as? Bool ?? false
        )
    }
}
