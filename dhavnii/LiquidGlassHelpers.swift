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
        if #available(macOS 26.0, *) {
            let glass: Glass = {
                var value = Glass.regular
                if let tint {
                    value = value.tint(tint)
                }
                if interactive {
                    value = value.interactive()
                }
                return value
            }()
            self
                .glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(strokeColor, lineWidth: 1)
                )
        } else {
            self
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(fallbackFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(strokeColor, lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    func liquidGlassButtonStyle(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        } else {
            self
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
            if #available(macOS 26.0, *) {
                Rectangle()
                    .fill(Color.clear)
                    .glassEffect(.regular, in: .rect(cornerRadius: 0))
            } else {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow, state: .active)
            }
        }
        .ignoresSafeArea()
    }
}
