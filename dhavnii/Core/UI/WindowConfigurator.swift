//
//  WindowConfigurator.swift
//  OpenWispher
//
//  Configures native glass window chrome with readable contrast.
//

import AppKit
import SwiftUI

internal struct WindowConfigurator: NSViewRepresentable {
    internal func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { return }
            configure(window: window)
        }
        return view
    }

    internal func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { [weak nsView] in
            guard let window = nsView?.window else { return }
            configure(window: window)
        }
    }

    @MainActor
    private func configure(window: NSWindow) {
        // Keep liquid-glass translucency, but avoid fully clear windows.
        window.isOpaque = false
        window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.92)

        // Make content extend under the titlebar so the traffic-light area
        // uses the same background as the body.
        window.styleMask.insert(.fullSizeContentView)

        // Match modern macOS chrome.
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true

        // Force a clean recomposite without changing opacity.
        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.setNeedsDisplay()
            contentView.needsDisplay = true
        }
        window.displayIfNeeded()
    }
}
