//
//  TTSNotchWindowController.swift
//  OpenWispher
//
//  Controller for the TTS notch overlay window.
//

import AppKit
import SwiftUI

internal final class TTSNotchWindowController {
    private var window: NSPanel?
    private var appState: AppState

    internal init(appState: AppState) {
        self.appState = appState
        setupWindow()
    }

    private func setupWindow() {
        guard let screen = NSScreen.main else { return }

        let windowWidth: CGFloat = UIConstants.NotchTTS.windowWidth
        let windowHeight: CGFloat = UIConstants.NotchTTS.windowHeight

        let xPosition = screen.frame.midX - (windowWidth / 2)
        let yPosition = screen.frame.maxY - windowHeight

        let contentRect = NSRect(
            x: xPosition,
            y: yPosition,
            width: windowWidth,
            height: windowHeight
        )

        let panel = DynamicIslandPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = false

        let hostingView = NonIntrinsicHostingView(rootView: TTSNotchOverlayView(appState: appState))
        hostingView.frame = contentRect
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        self.window = panel
    }

    internal func show() {
        window?.orderFront(nil)
    }

    internal func hide() {
        window?.orderOut(nil)
    }

    internal func updatePosition() {
        guard let screen = NSScreen.main, let window = window else { return }
        let windowWidth = window.frame.width
        let xPosition = screen.frame.midX - (windowWidth / 2)
        let yPosition = screen.frame.maxY - window.frame.height
        window.setFrameOrigin(NSPoint(x: xPosition, y: yPosition))
    }
}
