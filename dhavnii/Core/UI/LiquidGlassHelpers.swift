//
//  LiquidGlassHelpers.swift
//  OpenWispher
//
//  Shared Liquid Glass helpers and fallbacks.
//

import AppKit
import SwiftUI

extension View {
    @ViewBuilder
    func liquidGlassSurface(
        cornerRadius: CGFloat,
        tint: Color? = nil,
        interactive: Bool = false,
        fallbackFill: Color = Color.white.opacity(0.3),
        strokeColor: Color = Color.black.opacity(0.12)
    ) -> some View {
        let fillColor = tint ?? fallbackFill
        let opacity: Double = interactive ? 0.62 : 0.48

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
    func liquidGlassPanelBackground(
        material: NSVisualEffectView.Material = .windowBackground,
        tint: Color = Color.black.opacity(0.28),
        includeStroke: Bool = false
    ) -> some View {
        self
            .background(
                VisualEffectBlur(material: material, blendingMode: .withinWindow, state: .active)
                    .overlay(tint)
            )
            .overlay {
                if includeStroke {
                    Rectangle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                }
            }
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
        } else {
            self
        }
    }
}

internal struct LiquidGlassBackground: View {
    var body: some View {
        Group {
            VisualEffectBlur(
                material: .underWindowBackground, blendingMode: .behindWindow, state: .active
            )
            .overlay(Color.black.opacity(0.3))
        }
        .ignoresSafeArea()
    }
}
