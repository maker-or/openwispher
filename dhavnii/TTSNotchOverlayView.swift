//
//  TTSNotchOverlayView.swift
//  OpenWispher
//
//  Notch overlay for text-to-speech status and text display.
//

import SwiftUI

internal struct TTSNotchOverlayView: View {
    internal var appState: AppState

    private let pillWidth: CGFloat = UIConstants.NotchTTS.pillWidth
    private let pillHeight: CGFloat = UIConstants.NotchTTS.pillHeight

    @State private var horizontalScale: CGFloat = 0.3
    @State private var verticalScale: CGFloat = 0.3
    @State private var opacity: Double = 0.0
    @State private var verticalOffset: CGFloat = -20

    private var shouldShow: Bool {
        // The notch should NEVER show while generating (plain text state removed).
        // Once audio is ready and playback starts, it can remain visible until user closes it.
        appState.showTTSNotch
            && (appState.ttsState == .speaking || appState.ttsState == .paused || appState.ttsState == .idle)
    }

    var body: some View {
        ZStack(alignment: .top) {
            TTSNotchPillView(content: {
                TTSNotchContentView(appState: appState)
            })
            .frame(width: pillWidth, height: pillHeight)
            .padding(.top, 0)
            .frame(maxWidth: .infinity, alignment: .top)
            .scaleEffect(x: horizontalScale, y: verticalScale, anchor: .top)
            .opacity(opacity)
            .offset(y: verticalOffset)
            .allowsHitTesting(shouldShow)
        }
        .ignoresSafeArea(.all, edges: .top)
        .onChange(of: shouldShow) { _, newValue in
            if newValue {
                horizontalScale = 0.3
                verticalScale = 0.3
                opacity = 0.0
                verticalOffset = -20
                DispatchQueue.main.asyncAfter(deadline: .now() + UIConstants.Animation.delay) {
                    withAnimation(NotchAnimation.insertion) {
                        horizontalScale = 1.0
                        verticalScale = 1.0
                        opacity = 1.0
                        verticalOffset = 0
                    }
                }
            } else {
                withAnimation(NotchAnimation.removal) {
                    horizontalScale = 0.3
                    verticalScale = 0.3
                    opacity = 0.0
                    verticalOffset = -20
                }
            }
        }
        .onAppear {
            if shouldShow {
                horizontalScale = 1.0
                verticalScale = 1.0
                opacity = 1.0
                verticalOffset = 0
            }
        }
    }
}

internal struct TTSNotchContentView: View {
    internal var appState: AppState

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                stateIcon
                stateText
                    .lineLimit(1)

                Spacer()

                Button(action: {
                    appState.showTTSNotch = false
                    appState.currentlySpeaking = ""
                    appState.ttsProgress = 0.0
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            HStack {
                Text(appState.currentlySpeaking)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if appState.ttsState == .speaking || appState.ttsState == .paused {
                ProgressView(value: appState.ttsProgress)
                    .progressViewStyle(.linear)
                    .tint(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private var stateIcon: some View {
        switch appState.ttsState {
        case .speaking:
            Image(systemName: "speaker.wave.2.fill")
                .foregroundColor(.green)
                .font(.system(size: 16, weight: .semibold))
        case .paused:
            Image(systemName: "pause.fill")
                .foregroundColor(.yellow)
                .font(.system(size: 16, weight: .semibold))
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.system(size: 16, weight: .semibold))
        case .idle:
            Image(systemName: "speaker.wave.1.fill")
                .foregroundColor(.white.opacity(0.7))
                .font(.system(size: 16, weight: .semibold))
        case .generating:
            // Not shown (notch is hidden during generation), but keep for completeness.
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.7)
                .tint(.white)
        }
    }

    @ViewBuilder
    private var stateText: some View {
        switch appState.ttsState {
        case .speaking:
            Text("Speaking")
                .foregroundStyle(.white)
                .font(.system(size: 15, weight: .semibold))
        case .paused:
            Text("Paused")
                .foregroundStyle(.white)
                .font(.system(size: 15, weight: .semibold))
        case .error(let message):
            Text(message)
                .foregroundColor(.red)
                .font(.system(size: 14, weight: .semibold))
        case .idle:
            Text("Ready")
                .foregroundStyle(.white)
                .font(.system(size: 15, weight: .semibold))
        case .generating:
            // Not shown (notch is hidden during generation), but keep for completeness.
            Text("Generating")
                .foregroundStyle(.white)
                .font(.system(size: 15, weight: .semibold))
        }
    }
}

private struct TTSNotchPillView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private let topCornerRadius: CGFloat = UIConstants.NotchTTS.topCornerRadius
    private let bottomCornerRadius: CGFloat = UIConstants.NotchTTS.bottomCornerRadius

    var body: some View {
        ZStack {
            NotchShape(
                topCornerRadius: topCornerRadius,
                bottomCornerRadius: bottomCornerRadius
            )
            .fill(Color.black)
            .overlay(
                NotchShape(
                    topCornerRadius: topCornerRadius,
                    bottomCornerRadius: bottomCornerRadius
                )
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            content
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
        }
        .compositingGroup()
    }
}
