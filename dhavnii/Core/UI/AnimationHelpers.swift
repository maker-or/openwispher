//
//  AnimationHelpers.swift
//  OpenWispher
//
//  Enhanced animation utilities for smooth, production-ready UI animations.
//

import SwiftUI

// MARK: - Spring Configurations

/// Pre-configured spring animations for consistent feel throughout the app
internal enum SpringAnimation {
    /// Smooth, natural spring for general UI transitions
    static let smooth = Animation.spring(response: 0.5, dampingFraction: 0.75)

    /// Bouncy spring for playful elements
    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)

    /// Snappy spring for quick feedback
    static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.8)

    /// Gentle spring for subtle transitions
    static let gentle = Animation.spring(response: 0.6, dampingFraction: 0.85)

    /// Extra smooth spring for large movements
    static let extraSmooth = Animation.spring(response: 0.7, dampingFraction: 0.8)
}

// MARK: - Notch-specific Animations

/// Animation configurations specifically for the notch overlay
internal enum NotchAnimation {
    /// Insertion animation - growing from notch (smooth expansion)
    static let insertion = Animation.spring(
        response: 0.6,
        dampingFraction: 0.75,
        blendDuration: 0.25
    )

    /// Removal animation - shrinking back to notch (smooth contraction)
    static let removal = Animation.spring(
        response: 0.5,
        dampingFraction: 0.85,
        blendDuration: 0.2
    )

    /// State change animation (recording → processing, etc)
    static let stateChange = Animation.spring(
        response: 0.35,
        dampingFraction: 0.7
    )

    /// Heartbeat/pulse animation
    static let heartbeat = Animation.easeInOut(duration: 0.2)

    /// Rotation animation for processing indicator
    static let rotation = Animation.linear(duration: 1.5).repeatForever(autoreverses: false)
}

// MARK: - Easing Curves

/// Custom easing curves for specific use cases
internal enum EasingCurve {
    /// Smooth ease-in-out for general transitions
    static let standard = Animation.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 0.3)

    /// Ease-out for entering elements
    static let easeOut = Animation.timingCurve(0.0, 0.0, 0.2, 1.0, duration: 0.25)

    /// Ease-in for exiting elements
    static let easeIn = Animation.timingCurve(0.4, 0.0, 1.0, 1.0, duration: 0.2)

    /// Emphasized ease for important actions
    static let emphasized = Animation.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 0.5)
}

// MARK: - View Modifiers

/// Smooth scale animation modifier
internal struct SmoothScaleModifier: ViewModifier {
    let isActive: Bool
    let scale: CGFloat
    let animation: Animation

    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? scale : 1.0)
            .animation(animation, value: isActive)
    }
}

/// Smooth opacity animation modifier
internal struct SmoothOpacityModifier: ViewModifier {
    let isVisible: Bool
    let animation: Animation

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1.0 : 0.0)
            .animation(animation, value: isVisible)
    }
}

/// Smooth slide animation modifier
internal struct SmoothSlideModifier: ViewModifier {
    let isVisible: Bool
    let edge: Edge
    let distance: CGFloat
    let animation: Animation

    func body(content: Content) -> some View {
        content
            .offset(offsetFor(edge: edge, isVisible: isVisible, distance: distance))
            .opacity(isVisible ? 1.0 : 0.0)
            .animation(animation, value: isVisible)
    }

    private func offsetFor(edge: Edge, isVisible: Bool, distance: CGFloat) -> CGSize {
        if isVisible { return .zero }

        switch edge {
        case .top:
            return CGSize(width: 0, height: -distance)
        case .bottom:
            return CGSize(width: 0, height: distance)
        case .leading:
            return CGSize(width: -distance, height: 0)
        case .trailing:
            return CGSize(width: distance, height: 0)
        }
    }
}

/// Smooth rotation animation modifier
internal struct SmoothRotationModifier: ViewModifier {
    let isRotating: Bool
    let degrees: Double
    let animation: Animation

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isRotating ? degrees : 0))
            .animation(animation, value: isRotating)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply smooth scale animation
    func smoothScale(
        isActive: Bool, scale: CGFloat = 1.15, animation: Animation = SpringAnimation.smooth
    ) -> some View {
        modifier(SmoothScaleModifier(isActive: isActive, scale: scale, animation: animation))
    }

    /// Apply smooth opacity animation
    func smoothOpacity(isVisible: Bool, animation: Animation = SpringAnimation.smooth) -> some View
    {
        modifier(SmoothOpacityModifier(isVisible: isVisible, animation: animation))
    }

    /// Apply smooth slide animation
    func smoothSlide(
        isVisible: Bool, from edge: Edge = .top, distance: CGFloat = 20,
        animation: Animation = SpringAnimation.smooth
    ) -> some View {
        modifier(
            SmoothSlideModifier(
                isVisible: isVisible, edge: edge, distance: distance, animation: animation))
    }

    /// Apply smooth rotation animation
    func smoothRotate(
        isRotating: Bool, degrees: Double = 360, animation: Animation = SpringAnimation.smooth
    ) -> some View {
        modifier(
            SmoothRotationModifier(isRotating: isRotating, degrees: degrees, animation: animation))
    }

    /// Apply shimmer effect for loading states
    func shimmer(isActive: Bool = true) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }

    /// Apply pulse animation for attention-grabbing elements
    func pulse(isActive: Bool = true, scale: CGFloat = 1.05) -> some View {
        modifier(PulseModifier(isActive: isActive, scale: scale))
    }
}

// MARK: - Shimmer Effect

internal struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .white.opacity(0.3),
                        .clear,
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .opacity(isActive ? 1 : 0)
            )
            .onAppear {
                if isActive {
                    withAnimation(
                        Animation.linear(duration: 1.5).repeatForever(autoreverses: false)
                    ) {
                        phase = 300
                    }
                }
            }
    }
}

// MARK: - Pulse Effect

internal struct PulseModifier: ViewModifier {
    let isActive: Bool
    let scale: CGFloat
    @State private var isPulsing = false
    @State private var pulseTimer: Timer?

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? scale : 1.0)
            .onAppear {
                if isActive {
                    pulseTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                        withAnimation(SpringAnimation.bouncy) {
                            isPulsing = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(SpringAnimation.bouncy) {
                                isPulsing = false
                            }
                        }
                    }
                }
            }
            .onDisappear {
                pulseTimer?.invalidate()
                pulseTimer = nil
            }
    }
}

// MARK: - Transition Extensions

extension AnyTransition {
    /// Smooth scale and fade transition
    static var scaleFade: AnyTransition {
        .scale(scale: 0.9).combined(with: .opacity)
    }

    /// Smooth slide from top
    static var slideFromTop: AnyTransition {
        .move(edge: .top).combined(with: .opacity)
    }

    /// Smooth slide from bottom
    static var slideFromBottom: AnyTransition {
        .move(edge: .bottom).combined(with: .opacity)
    }

    /// Notch-style expansion with smooth horizontal expansion
    static var notchExpansion: AnyTransition {
        .asymmetric(
            insertion: .asymmetric(
                insertion: .scale(scale: 0.3, anchor: .top)
                    .combined(with: .opacity)
                    .combined(with: .move(edge: .top)),
                removal: .identity
            )
            .animation(.spring(response: 0.6, dampingFraction: 0.75)),
            removal: .asymmetric(
                insertion: .identity,
                removal: .scale(scale: 0.3, anchor: .top)
                    .combined(with: .opacity)
                    .combined(with: .move(edge: .top))
            )
            .animation(.spring(response: 0.5, dampingFraction: 0.85))
        )
    }
    
    /// Smooth horizontal expansion from center (for notch effect)
    static var horizontalExpansion: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: ExpansionModifier(scale: 0.3, opacity: 0),
                identity: ExpansionModifier(scale: 1.0, opacity: 1)
            )
            .animation(.spring(response: 0.6, dampingFraction: 0.75)),
            removal: .modifier(
                active: ExpansionModifier(scale: 0.3, opacity: 0),
                identity: ExpansionModifier(scale: 1.0, opacity: 1)
            )
            .animation(.spring(response: 0.5, dampingFraction: 0.85))
        )
    }

    /// Smooth blur transition
    static var blur: AnyTransition {
        .modifier(
            active: BlurModifier(radius: 10),
            identity: BlurModifier(radius: 0)
        )
    }
}

// MARK: - Blur Modifier

internal struct BlurModifier: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .blur(radius: radius)
    }
}

// MARK: - Expansion Modifier

/// Modifier for smooth horizontal expansion animation
internal struct ExpansionModifier: ViewModifier {
    let scale: CGFloat
    let opacity: Double
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(x: scale, y: 1.0, anchor: .top)
            .opacity(opacity)
    }
}

// MARK: - Timing Functions

/// Utility for creating custom timing functions
internal struct TimingFunction {
    /// Calculate value at given progress using cubic bezier
    static func cubicBezier(p1: CGPoint, p2: CGPoint, progress: Double) -> Double {
        let t = progress
        let t2 = t * t
        let t3 = t2 * t
        let mt = 1 - t
        let mt2 = mt * mt
        let _ = mt2 * mt  // mt3 - reserved for future use

        return 3 * mt2 * t * Double(p1.y)
            + 3 * mt * t2 * Double(p2.y)
            + t3
    }

    /// Ease in out function
    static func easeInOut(progress: Double) -> Double {
        return cubicBezier(p1: CGPoint(x: 0.4, y: 0), p2: CGPoint(x: 0.2, y: 1), progress: progress)
    }

    /// Ease out function
    static func easeOut(progress: Double) -> Double {
        return cubicBezier(p1: CGPoint(x: 0, y: 0), p2: CGPoint(x: 0.2, y: 1), progress: progress)
    }
}

// MARK: - Performance Optimization

/// Helpers for optimizing animation performance
extension View {
    /// Optimize drawing performance during animations
    func optimizeForAnimation() -> some View {
        self
            .drawingGroup()  // Use Metal rendering
    }

    /// Reduce animation work when off-screen
    func reduceMotionIfNeeded() -> some View {
        self.transaction { transaction in
            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                transaction.animation = nil
            }
        }
    }
}
