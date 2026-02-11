//
//  HotkeyManager.swift
//  OpenWispher
//
//  Global hotkey manager for Option+Space shortcut.
//

import Foundation
import Carbon
import Cocoa

// MARK: - Hotkey Definition

internal struct HotkeyDefinition: Equatable {
    internal static let keyCodeDefaultsKey = "hotkeyKeyCode"
    internal static let modifiersDefaultsKey = "hotkeyModifiers"
    internal static let defaultHotkey = HotkeyDefinition(
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(optionKey)
    )

    internal let keyCode: UInt32
    internal let modifiers: UInt32

    internal static func loadFromDefaults() -> HotkeyDefinition {
        let defaults = UserDefaults.standard
        let storedKeyCode = defaults.object(forKey: keyCodeDefaultsKey) as? Int
        let storedModifiers = defaults.object(forKey: modifiersDefaultsKey) as? Int

        return HotkeyDefinition(
            keyCode: UInt32(storedKeyCode ?? Int(defaultHotkey.keyCode)),
            modifiers: UInt32(storedModifiers ?? Int(defaultHotkey.modifiers))
        )
    }

    internal func saveToDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(Int(keyCode), forKey: HotkeyDefinition.keyCodeDefaultsKey)
        defaults.set(Int(modifiers), forKey: HotkeyDefinition.modifiersDefaultsKey)
    }

    internal var displayString: String {
        HotkeyDefinition.displayString(for: self)
    }

    internal static func displayString(for hotkey: HotkeyDefinition) -> String {
        let modifierSymbols = modifierSymbols(for: hotkey.modifiers)
        let keyName = keyDisplayName(for: hotkey.keyCode)
        return modifierSymbols + " + " +  keyName
    }

    internal static func modifiersFrom(flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        return modifiers
    }

    private static func modifierSymbols(for modifiers: UInt32) -> String {
        var symbols = ""
        if modifiers & UInt32(controlKey) != 0 { symbols += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { symbols += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { symbols += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { symbols += "⌘" }
        return symbols
    }

    private static func keyDisplayName(for keyCode: UInt32) -> String {
        switch keyCode {
        case UInt32(kVK_Space): return "Space"
        case UInt32(kVK_Return): return "Return"
        case UInt32(kVK_Tab): return "Tab"
        case UInt32(kVK_Delete): return "Delete"
        case UInt32(kVK_Escape): return "Esc"
        case UInt32(kVK_LeftArrow): return "Left"
        case UInt32(kVK_RightArrow): return "Right"
        case UInt32(kVK_UpArrow): return "Up"
        case UInt32(kVK_DownArrow): return "Down"
        default:
            if let translated = keyStringFromKeyCode(UInt16(keyCode)) {
                let trimmed = translated.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed.uppercased()
                }
            }
            return "Key \(keyCode)"
        }
    }

    private static func keyStringFromKeyCode(_ keyCode: UInt16) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() else {
            return nil
        }
        guard let layoutDataPointer = TISGetInputSourceProperty(
            source,
            kTISPropertyUnicodeKeyLayoutData
        ) else {
            return nil
        }

        let layoutData = unsafeBitCast(layoutDataPointer, to: CFData.self)
        guard let data = CFDataGetBytePtr(layoutData) else { return nil }
        let keyboardLayout = UnsafePointer<UCKeyboardLayout>(OpaquePointer(data))

        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 8)

        let result = UCKeyTranslate(
            keyboardLayout,
            keyCode,
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            characters.count,
            &length,
            &characters
        )

        guard result == noErr else { return nil }
        return String(utf16CodeUnits: characters, count: length)
    }
}

/// Manages global hotkey registration using Carbon API for robustness
/// 
/// Memory Safety: Uses Unmanaged.passRetained to ensure the instance stays alive
/// while the Carbon event handler is installed. The retain is balanced by
/// takeRetainedValue in the callback or by explicit release in stopMonitoring.
class HotkeyManager {
    private var eventHandler: EventHandlerRef?
    private var hotkeyRef: EventHotKeyRef?
    private var lastTriggerTime: Date = .distantPast
    private var selfPointer: UnsafeMutableRawPointer?
    private var hotkeyDefinition: HotkeyDefinition
    
    // Callback triggered when the hotkey is pressed
    let onTrigger: () -> Void
    
    init(hotkey: HotkeyDefinition = .defaultHotkey, onTrigger: @escaping () -> Void) {
        self.hotkeyDefinition = hotkey
        self.onTrigger = onTrigger
    }
    
    internal var currentHotkey: HotkeyDefinition {
        hotkeyDefinition
    }
    
    /// Start monitoring for the configured hotkey
    @discardableResult
    func startMonitoring() -> Bool {
        stopMonitoring()
        
        // Define the hotkey ID
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x4448564E) // "DHVN"
        hotKeyID.id = 1
        
        // Register the hotkey
        let status = RegisterEventHotKey(
            hotkeyDefinition.keyCode,
            hotkeyDefinition.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
        
        if status != noErr {
            print("Failed to register hotkey: \(status)")
            return false
        }
        
        // Install the event handler
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        // Pass retained 'self' as user data to the callback
        // This ensures the instance stays alive while the handler is installed
        selfPointer = Unmanaged.passRetained(self).toOpaque()
        
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, event, userData) -> OSStatus in
                // Recover the instance - take retained value to balance the passRetained
                guard let userData = userData else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                
                // Trigger the callback on main thread
                DispatchQueue.main.async {
                    // Debounce: Ignore triggers within 0.5 seconds
                    if Date().timeIntervalSince(manager.lastTriggerTime) > 0.5 {
                        manager.lastTriggerTime = Date()
                        manager.onTrigger()
                    }
                }
                
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandler
        )
        
        if handlerStatus != noErr {
            print("Failed to install hotkey handler: \(handlerStatus)")
            if let ref = hotkeyRef {
                UnregisterEventHotKey(ref)
                hotkeyRef = nil
            }
            if let pointer = selfPointer {
                Unmanaged<HotkeyManager>.fromOpaque(pointer).release()
                selfPointer = nil
            }
            return false
        }
        
        return true
    }

    @discardableResult
    func updateHotkey(_ newHotkey: HotkeyDefinition) -> Bool {
        let previousHotkey = hotkeyDefinition
        hotkeyDefinition = newHotkey
        let success = startMonitoring()
        if success {
            return true
        }

        hotkeyDefinition = previousHotkey
        _ = startMonitoring()
        return false
    }
    
    func stopMonitoring() {
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        
        // Release the retain we did in startMonitoring
        if let pointer = selfPointer {
            Unmanaged<HotkeyManager>.fromOpaque(pointer).release()
            selfPointer = nil
        }
    }
    
    deinit {
        stopMonitoring()
    }
}

// MARK: - Escape Key Monitor

internal final class EscapeKeyMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let onEscape: () -> Void

    internal init(onEscape: @escaping () -> Void) {
        self.onEscape = onEscape
    }

    internal func start() {
        stop()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == UInt16(kVK_Escape) else {
                return event
            }
            self?.onEscape()
            return nil
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == UInt16(kVK_Escape) else { return }
            DispatchQueue.main.async {
                self?.onEscape()
            }
        }
    }

    internal func stop() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }

        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }

    deinit {
        stop()
    }
}
