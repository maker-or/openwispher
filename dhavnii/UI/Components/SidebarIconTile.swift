//
//  SidebarIconTile.swift
//  OpenWispher
//
//  Gradient icon tile for sidebar navigation.
//

import SwiftUI

internal struct SidebarIconTile: View {
    let systemName: String
    let colors: [Color]
    let size: CGFloat
    let symbolSize: CGFloat

    init(
        systemName: String,
        colors: [Color],
        size: CGFloat = 28,
        symbolSize: CGFloat = 14
    ) {
        self.systemName = systemName
        self.colors = colors
        self.size = size
        self.symbolSize = symbolSize
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.35),
                                    Color.white.opacity(0.02),
                                    Color.clear,
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.screen)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.6)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)

            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: Color.black.opacity(0.25), radius: 1, x: 0, y: 1)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
