//
//  NotchOverlayView.swift
//  OpenWispher
//
//  Notch-integrated overlay that expands from the MacBook notch.
//  Based on Atoll's DynamicIsland implementation.
//  Enhanced with production-ready smooth animations.
//

import SwiftUI

/// Notch overlay view that expands from the top center
internal struct NotchOverlayView: View {
    internal var appState: AppState

    private var shouldShow: Bool {
        switch appState.recordingState {
        case .idle:
            return false
        default:
            return true
        }
    }

    // Fixed size to prevent constraint loops
    // Increased height to ensure content clears the physical notch (32pt)
    private let pillWidth: CGFloat = UIConstants.NotchSTT.pillWidth
    private let pillHeight: CGFloat = UIConstants.NotchSTT.pillHeight

    @State private var horizontalScale: CGFloat = 0.3
    @State private var verticalScale: CGFloat = 0.3
    @State private var opacity: Double = 0.0
    @State private var verticalOffset: CGFloat = -20
    var body: some View {
        ZStack(alignment: .top) {
            NotchPillView(
                content: {
                    NotchContentView(state: appState.recordingState)
                }
            )
            .frame(width: pillWidth, height: pillHeight)
            .padding(.top, 0)
            .frame(maxWidth: .infinity, alignment: .top)
            .scaleEffect(x: horizontalScale, y: verticalScale, anchor: .top)
            .opacity(opacity)
            .offset(y: verticalOffset)
            .allowsHitTesting(shouldShow) // Only accept interactions when visible
        }
        .ignoresSafeArea(.all, edges: .top)
        .onChange(of: shouldShow) { oldValue, newValue in
            if newValue {
                // Appearing: expand smoothly from small notch size
                // Start with small scale and fade in
                horizontalScale = 0.3
                verticalScale = 0.3
                opacity = 0.0
                verticalOffset = -20
                
                // Small delay to ensure view is in hierarchy before animating
                DispatchQueue.main.asyncAfter(deadline: .now() + UIConstants.Animation.delay) {
                    // Animate to full size with smooth spring
                    withAnimation(NotchAnimation.insertion) {
                        horizontalScale = 1.0
                        verticalScale = 1.0
                        opacity = 1.0
                        verticalOffset = 0
                    }
                }
            } else {
                // Disappearing: contract smoothly back to notch position
                withAnimation(NotchAnimation.removal) {
                    horizontalScale = 0.3
                    verticalScale = 0.3
                    opacity = 0.0
                    verticalOffset = -20
                }
            }
        }
        .onAppear {
            // Initialize state based on shouldShow
            if shouldShow {
                horizontalScale = 1.0
                verticalScale = 1.0
                opacity = 1.0
                verticalOffset = 0
            }
        }
    }
}

/// Notch-style pill container using Atoll's NotchShape
private struct NotchPillView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    // Fixed corner radius values
    private let topCornerRadius: CGFloat = UIConstants.NotchSTT.topCornerRadius
    private let bottomCornerRadius: CGFloat = UIConstants.NotchSTT.bottomCornerRadius

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
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
        }
        .compositingGroup()
    }
}

/// NotchShape from Atoll - creates the signature notch geometry
internal struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get {
            .init(topCornerRadius, bottomCornerRadius)
        }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(
            to: CGPoint(
                x: rect.minX,
                y: rect.minY
            )
        )

        path.addQuadCurve(
            to: CGPoint(
                x: rect.minX + topCornerRadius,
                y: rect.minY + topCornerRadius
            ),
            control: CGPoint(
                x: rect.minX + topCornerRadius,
                y: rect.minY
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.minX + topCornerRadius,
                y: rect.maxY - bottomCornerRadius
            )
        )

        path.addQuadCurve(
            to: CGPoint(
                x: rect.minX + topCornerRadius + bottomCornerRadius,
                y: rect.maxY
            ),
            control: CGPoint(
                x: rect.minX + topCornerRadius,
                y: rect.maxY
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.maxX - topCornerRadius - bottomCornerRadius,
                y: rect.maxY
            )
        )

        path.addQuadCurve(
            to: CGPoint(
                x: rect.maxX - topCornerRadius,
                y: rect.maxY - bottomCornerRadius
            ),
            control: CGPoint(
                x: rect.maxX - topCornerRadius,
                y: rect.maxY
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.maxX - topCornerRadius,
                y: rect.minY + topCornerRadius
            )
        )

        path.addQuadCurve(
            to: CGPoint(
                x: rect.maxX,
                y: rect.minY
            ),
            control: CGPoint(
                x: rect.maxX - topCornerRadius,
                y: rect.minY
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.minX,
                y: rect.minY
            )
        )

        return path
    }
}

/// Content displayed inside the notch overlay
internal struct NotchContentView: View {
    internal let state: RecordingState
    @State private var isAnimating = false

    internal var body: some View {
        HStack(spacing: 10) {
            stateIcon
                .transition(.scaleFade)
            stateText
                .lineLimit(1)
                .transition(.slideFromTop)
        }
        .fixedSize(horizontal: true, vertical: false)
        .offset(y: 16)
        .onAppear {
            withAnimation(NotchAnimation.stateChange) {
                isAnimating = true
            }
        }
        .onChange(of: state) { oldValue, newValue in
            withAnimation(NotchAnimation.stateChange) {
                isAnimating = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(NotchAnimation.stateChange) {
                    isAnimating = true
                }
            }
        }
    }

    @ViewBuilder
    private var stateIcon: some View {
        switch state {
        case .recording:
            MicrophoneIcon()
        case .processing:
            ProcessingIndicator()
        case .success:
            SuccessIcon()
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.system(size: 16, weight: .semibold))
        case .idle:
            EmptyView()
        }
    }

    @ViewBuilder
    private var stateText: some View {
        switch state {
        case .recording:
            Text("Listening")
                .foregroundStyle(.white)
                .font(.system(size: 14, weight: .semibold))
        case .processing:
            Text("Processing")
                .foregroundStyle(.white)
                .font(.system(size: 14, weight: .semibold))
        case .success:
            Text("Copied!")
                .foregroundColor(.green)
                .font(.system(size: 14, weight: .semibold))
        case .error(let message):
            Text(message)
                .foregroundColor(.red)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
        case .idle:
            EmptyView()
        }
    }
}

/// Animated microphone icon with heartbeat animation
internal struct MicrophoneIcon: View {
    @State private var isBeating = false
    @State private var beatTimer: Timer?

    var body: some View {
        ZStack {
            // Outer border
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color(hex: "281211"), lineWidth: 2)
                .frame(width: 20, height: 20)

            // 3x3 grid of colored squares
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Rectangle().fill(Color(hex: "A96365")).frame(width: 5.5, height: 5.5)
                    Rectangle().fill(Color(hex: "FFA0A0")).frame(width: 5.5, height: 5.5)
                    Rectangle().fill(Color(hex: "A96365")).frame(width: 5.5, height: 5.5)
                }
                HStack(spacing: 0) {
                    Rectangle().fill(Color(hex: "FFA0A0")).frame(width: 5.5, height: 5.5)
                    Rectangle().fill(Color(hex: "DD8684")).frame(width: 5.5, height: 5.5)
                    Rectangle().fill(Color(hex: "FFA0A0")).frame(width: 5.5, height: 5.5)
                }
                HStack(spacing: 0) {
                    Rectangle().fill(Color(hex: "A96365")).frame(width: 5.5, height: 5.5)
                    Rectangle().fill(Color(hex: "FFA0A0")).frame(width: 5.5, height: 5.5)
                    Rectangle().fill(Color(hex: "A96365")).frame(width: 5.5, height: 5.5)
                }
            }
            .frame(width: 16.5, height: 16.5)
        }
        .frame(width: 20, height: 20)
        .scaleEffect(isBeating ? 1.12 : 1.0)
        .onAppear {
            startHeartbeat()
        }
        .onDisappear {
            beatTimer?.invalidate()
            beatTimer = nil
        }
    }

    private func startHeartbeat() {
        // Heartbeat pattern: beat-beat-pause (slower, more natural)
        beatTimer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: true) { _ in
            // First beat
            withAnimation(NotchAnimation.heartbeat) {
                isBeating = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(NotchAnimation.heartbeat) {
                    isBeating = false
                }
            }
            // Second beat
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(NotchAnimation.heartbeat) {
                    isBeating = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(NotchAnimation.heartbeat) {
                    isBeating = false
                }
            }
        }
    }
}

/// Success icon - green SVG checkmark
internal struct SuccessIcon: View {
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            // Outer border
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color(hex: "112811"), lineWidth: 2)
                .frame(width: 20, height: 20)

            // 3x3 grid of green squares
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Rectangle().fill(Color(hex: "65A965")).frame(width: 5.5, height: 5.5)
                    Rectangle().fill(Color(hex: "A0FFA0")).frame(width: 5.5, height: 5.5)
                    Rectangle().fill(Color(hex: "65A965")).frame(width: 5.5, height: 5.5)
                }
                HStack(spacing: 0) {
                    Rectangle().fill(Color(hex: "A0FFA0")).frame(width: 5.5, height: 5.5)
                    Rectangle().fill(Color(hex: "84DD86")).frame(width: 5.5, height: 5.5)
                    Rectangle().fill(Color(hex: "A0FFA0")).frame(width: 5.5, height: 5.5)
                }
                HStack(spacing: 0) {
                    Rectangle().fill(Color(hex: "65A965")).frame(width: 5.5, height: 5.5)
                    Rectangle().fill(Color(hex: "A0FFA0")).frame(width: 5.5, height: 5.5)
                    Rectangle().fill(Color(hex: "65A965")).frame(width: 5.5, height: 5.5)
                }
            }
            .frame(width: 16.5, height: 16.5)
        }
        .frame(width: 20, height: 20)
        .scaleEffect(hasAppeared ? 1.0 : 0.5)
        .opacity(hasAppeared ? 1.0 : 0.0)
        .onAppear {
            withAnimation(SpringAnimation.bouncy) {
                hasAppeared = true
            }
        }
    }
}

/// Processing indicator - yellow SVG with rotating animation
internal struct ProcessingIndicator: View {
    @State private var isRotating = false

    var body: some View {
        ZStack {
            // Outer border
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color(hex: "282811"), lineWidth: 2)
                .frame(width: 20, height: 20)

            // 3x3 grid of yellow squares
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Rectangle().fill(Color(hex: "A9A365")).frame(width: 5.5, height: 5.5)
                    Rectangle().fill(Color(hex: "FFF0A0")).frame(width: 5.5, height: 5.5)
                    Rectangle().fill(Color(hex: "A9A365")).frame(width: 5.5, height: 5.5)
                }
                HStack(spacing: 0) {
                    Rectangle().fill(Color(hex: "FFF0A0")).frame(width: 5.5, height: 5.5)
                    Rectangle().fill(Color(hex: "DDD084")).frame(width: 5.5, height: 5.5)
                    Rectangle().fill(Color(hex: "FFF0A0")).frame(width: 5.5, height: 5.5)
                }
                HStack(spacing: 0) {
                    Rectangle().fill(Color(hex: "A9A365")).frame(width: 5.5, height: 5.5)
                    Rectangle().fill(Color(hex: "FFF0A0")).frame(width: 5.5, height: 5.5)
                    Rectangle().fill(Color(hex: "A9A365")).frame(width: 5.5, height: 5.5)
                }
            }
            .frame(width: 16.5, height: 16.5)
        }
        .frame(width: 20, height: 20)
        .rotationEffect(.degrees(isRotating ? 360 : 0))
        .animation(NotchAnimation.rotation, value: isRotating)
        .onAppear {
            isRotating = true
        }
    }
}

/// Color extension to support hex strings
internal extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
