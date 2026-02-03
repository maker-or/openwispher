//
//  VisualEffectBlur.swift
//  OpenWispher
//
//  NSVisualEffectView wrapper for macOS “glass” backgrounds.
//

import AppKit
import SwiftUI

internal struct VisualEffectBlur: NSViewRepresentable {
    internal var material: NSVisualEffectView.Material
    internal var blendingMode: NSVisualEffectView.BlendingMode
    internal var state: NSVisualEffectView.State

    internal init(
        material: NSVisualEffectView.Material = .sidebar,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    internal func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    internal func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

