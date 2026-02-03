//
//  NotchWindowController.swift
//  OpenWispher
//
//  Controller for the transparent notch overlay window.
//  Based on Atoll's DynamicIslandWindow implementation.
//

import AppKit
import Foundation
import SwiftUI

/// Controller for the floating notch overlay window
class NotchWindowController {
    private var window: NSPanel?
    private var appState: AppState

    init(appState: AppState) {
        self.appState = appState
        setupWindow()
    }

    private func setupWindow() {
        guard let screen = NSScreen.main else { return }

        // Calculate window dimensions based on the expanded notch size
        // The window needs to be large enough to contain the expanded notch + shadow
        let windowWidth: CGFloat = UIConstants.NotchSTT.windowWidth
        let windowHeight: CGFloat = UIConstants.NotchSTT.windowHeight

        let xPosition = screen.frame.midX - (windowWidth / 2)
        let yPosition = screen.frame.maxY - windowHeight

        let contentRect = NSRect(
            x: xPosition,
            y: yPosition,
            width: windowWidth,
            height: windowHeight
        )

        // Create a DynamicIslandPanel with Atoll's configuration
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
        panel.ignoresMouseEvents = true

        // Use custom hosting view that disables intrinsic size reporting
        let hostingView = NonIntrinsicHostingView(rootView: NotchOverlayView(appState: appState))
        hostingView.frame = contentRect
        hostingView.autoresizingMask = [.width, .height]

        panel.contentView = hostingView

        self.window = panel
    }

    func show() {
        window?.orderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }

    func updatePosition() {
        guard let screen = NSScreen.main, let window = window else { return }
        let windowWidth = window.frame.width
        let xPosition = screen.frame.midX - (windowWidth / 2)
        let yPosition = screen.frame.maxY - window.frame.height
        window.setFrameOrigin(NSPoint(x: xPosition, y: yPosition))
    }
}

/// Custom NSPanel configured like Atoll's DynamicIslandWindow
class DynamicIslandPanel: NSPanel {
    override init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: backing,
            defer: flag
        )

        isFloatingPanel = true
        isOpaque = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .clear
        isMovable = false

        collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle,
        ]

        isReleasedWhenClosed = false
        level = .statusBar + 1
        hasShadow = false
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

/// Custom NSHostingView that disables intrinsic content size to prevent layout loops
class NonIntrinsicHostingView<Content: View>: NSHostingView<Content> {
    override var intrinsicContentSize: NSSize {
        // Return invalid size to disable intrinsic sizing
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override func invalidateIntrinsicContentSize() {
        // Do nothing - prevents SwiftUI from triggering constraint updates
    }
}
