//
//  HotkeyManager.swift
//  OpenWispher
//
//  Global hotkey manager for Option+Space shortcut.
//

import Foundation
import Carbon
import Cocoa

/// Manages global hotkey registration using Carbon API for robustness
class HotkeyManager {
    private var eventHandler: EventHandlerRef?
    private var hotkeyRef: EventHotKeyRef?
    private var lastTriggerTime: Date = .distantPast
    
    // Callback triggered when the hotkey is pressed
    let onTrigger: () -> Void
    
    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }
    
    /// Start monitoring for Option+Space
    func startMonitoring() {
        // Define the hotkey ID
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x4448564E) // "DHVN"
        hotKeyID.id = 1
        
        // Register the hotkey: Option (2048/optionKey) + Space (49/kVK_Space)
        let status = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
        
        if status != noErr {
            print("Failed to register hotkey: \(status)")
            return
        }
        
        // Install the event handler
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        // Pass 'self' as user data to the callback
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, event, userData) -> OSStatus in
                // Recover the instance
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
    }
    
    deinit {
        stopMonitoring()
    }
}
