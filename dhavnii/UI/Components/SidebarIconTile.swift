//
//  SidebarIconTile.swift
//  OpenWispher
//
//  Gradient icon tile for sidebar navigation.
//

import SwiftUI

internal struct SidebarIconTile: View {
    let systemName: String
    let color: Color
    let size: CGFloat
    let symbolSize: CGFloat

    init(
        systemName: String,
        color: Color = Color.white.opacity(0.15),
        size: CGFloat = 28,
        symbolSize: CGFloat = 14
    ) {
        self.systemName = systemName
        self.color = color
        self.size = size
        self.symbolSize = symbolSize
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(color)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.6)
                )

            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.80))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
