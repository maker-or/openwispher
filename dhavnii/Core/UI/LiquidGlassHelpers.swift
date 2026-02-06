//
//  LiquidGlassHelpers.swift
//  OpenWispher
//
//  Shared Liquid Glass helpers and fallbacks.
//

import SwiftUI

internal extension View {
    @ViewBuilder
    func liquidGlassSurface(
        cornerRadius: CGFloat,
        tint: Color? = nil,
        interactive: Bool = false,
        fallbackFill: Color = Color.white.opacity(0.3),
        strokeColor: Color = Color.black.opacity(0.12)
    ) -> some View {
        let fillColor = tint ?? fallbackFill
        let opacity: Double = interactive ? 0.5 : 0.35

        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(fillColor.opacity(opacity))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            )
    }

    @ViewBuilder
    func liquidGlassButtonStyle(prominent: Bool = false) -> some View {
        if prominent {
            self.buttonStyle(.borderedProminent)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    func liquidGlassWindowBackground() -> some View {
        self.background(LiquidGlassBackground())
    }

    @ViewBuilder
    func seamlessToolbarWindowBackground() -> some View {
        if #available(macOS 15.0, *) {
            self
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                .containerBackground(.ultraThinMaterial, for: .window)
        } else {
            self
        }
    }
}

internal struct LiquidGlassBackground: View {
    var body: some View {
        Group {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow, state: .active)
        }
        .ignoresSafeArea()
    }
}
