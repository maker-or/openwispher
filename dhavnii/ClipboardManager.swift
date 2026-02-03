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
    
    /// Copy text to the system clipboard
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    /// Check if a text input field is currently focused
    func isTextFieldFocused() -> Bool {
        // Use Accessibility API to check if focused element is a text field
        guard let focusedApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }
        
        let appElement = AXUIElementCreateApplication(focusedApp.processIdentifier)
        
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        guard result == .success, let element = focusedElement else {
            return false
        }
        
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element as! AXUIElement, kAXRoleAttribute as CFString, &role)
        
        if let roleString = role as? String {
            // Broaden supported roles to include web areas and editors (VS Code, Chrome, etc.)
            let textRoles = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField", "AXWebArea", "AXGroup", "AXStaticText"]
            return textRoles.contains(roleString)
        }
        
        return false
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
        
        if AXIsProcessTrusted() {
            // Ensure OpenWispher is not the active app (stealing focus)
            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier {
                NSApp.hide(nil)
            }
            
            // Delay to allow focus to settle/switch back
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.simulatePaste()
            }
        }
    }
}
