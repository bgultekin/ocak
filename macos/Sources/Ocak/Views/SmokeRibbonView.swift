import SwiftUI

/// Smoke-style ribbon: a soft atmospheric plume bleeding inward from the screen edge.
/// Uses Metal shader with multi-layered fbm for organic turbulence when available,
/// falls back to SwiftUI-based wisps otherwise.
struct SmokeRibbonView: View {
    let store: SessionStore

    private static let opacityScale: Double = 0.5

    @State private var wisp1Offset: CGFloat = 0
    @State private var wisp2Offset: CGFloat = 0
    @State private var wisp3Offset: CGFloat = 0
    @State private var wisp1Opacity: Double = 0
    @State private var wisp2Opacity: Double = 0
    @State private var wisp3Opacity: Double = 0
    @State private var wisp1Scale: CGFloat = 1
    @State private var wisp2Scale: CGFloat = 1
    @State private var wisp3Scale: CGFloat = 1
    @State private var metalPulseScale: Float = 1.0
    @State private var nudgeOffset: CGFloat = 0
    @State private var flashOpacity: Double = 0
    @State private var metalAvailable = false

    private var smokeColor: Color {
        if store.hasAttention { return OcakTheme.statusAmber }
        if store.hasWorking { return OcakTheme.statusBlue }
        return .gray
    }

    var body: some View {
        if metalAvailable {
            metalContent
        } else {
            fallbackContent
        }
    }

    // MARK: - Metal-based rendering

    @ViewBuilder
    private var metalContent: some View {
        GeometryReader { geo in
            ZStack {
                MetalSmokeRibbonView(
                    density: metalDensity,
                    turbulenceScale: metalTurbulenceScale,
                    edgeDissipation: metalEdgeDissipation,
                    smokeColor: smokeColor.opacity(metalAlpha),
                    pulseScale: metalPulseScale
                )

                // Completion flash overlay
                if showFlash {
                    LinearGradient(
                        colors: [OcakTheme.statusGreen.opacity(flashOpacity), .clear],
                        startPoint: .trailing,
                        endPoint: .leading
                    )
                }
            }
        }
        .onChange(of: store.lastCompletionTime) { _, _ in
            flashAnimation()
        }
    }

    private var metalDensity: Float {
        if store.hasAttention { return 1.4 }
        if store.hasWorking { return 1.1 }
        return 0.8
    }

    private var metalTurbulenceScale: Float {
        store.hasWorking ? 1.3 : 0.8
    }

    private var metalEdgeDissipation: Float {
        0.45
    }

    private var metalAlpha: Double {
        let base: Double
        if store.hasAttention { base = 0.70 }
        else if store.hasWorking { base = 0.55 }
        else { base = 0.35 }
        return base * Self.opacityScale
    }

    // MARK: - SwiftUI fallback

    @ViewBuilder
    private var fallbackContent: some View {
        GeometryReader { geo in
            ZStack {
                // Base gradient: screen edge (trailing/right) is colored, fades to clear inward
                LinearGradient(
                    colors: [smokeColor.opacity(baseOpacity), .clear],
                    startPoint: .trailing,
                    endPoint: .leading
                )

                // Animated wisps when working
                if store.hasWorking {
                    smokeWisp(geo: geo, yFraction: 0.28, yOffset: wisp1Offset, opacity: wisp1Opacity,
                              scale: wisp1Scale, width: 28, height: 90)
                    smokeWisp(geo: geo, yFraction: 0.58, yOffset: wisp2Offset, opacity: wisp2Opacity,
                              scale: wisp2Scale, width: 22, height: 70)
                    smokeWisp(geo: geo, yFraction: 0.76, yOffset: wisp3Offset, opacity: wisp3Opacity,
                              scale: wisp3Scale, width: 26, height: 80)
                }

                // Completion flash
                if showFlash {
                    LinearGradient(
                        colors: [OcakTheme.statusGreen.opacity(flashOpacity), .clear],
                        startPoint: .trailing,
                        endPoint: .leading
                    )
                }
            }
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.12),
                    .init(color: .black, location: 0.88),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .offset(x: nudgeOffset)
        .onChange(of: store.hasAttention) { _, newValue in
            if newValue { nudgeAnimation() }
        }
        .onChange(of: store.hasWorking) { _, newValue in
            if newValue { startWispAnimations() }
            else { stopWisps() }
        }
        .onChange(of: store.lastCompletionTime) { _, _ in
            flashAnimation()
        }
        .onAppear {
            if store.hasWorking { startWispAnimations() }
        }
    }

    @ViewBuilder
    private func smokeWisp(geo: GeometryProxy, yFraction: CGFloat, yOffset: CGFloat,
                           opacity: Double, scale: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        Ellipse()
            .fill(smokeColor)
            .frame(width: width, height: height)
            .scaleEffect(scale)
            .blur(radius: 10)
            .opacity(opacity * 0.3 * Self.opacityScale)
            .position(x: geo.size.width * 0.75, y: geo.size.height * yFraction + yOffset)
    }

    private var baseOpacity: Double {
        let base: Double
        if store.hasAttention { base = 0.40 }
        else if store.hasWorking { base = 0.28 }
        else { base = 0.18 }
        return base * Self.opacityScale
    }

    private var showFlash: Bool {
        guard let t = store.lastCompletionTime else { return false }
        return Date().timeIntervalSince(t) < 2.0
    }

    private func startWispAnimations() {
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
            wisp1Offset = -25
        }
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
            wisp1Opacity = 1.0
        }
        withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
            wisp1Scale = 1.15
        }
        withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true).delay(0.9)) {
            wisp2Offset = -30
        }
        withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true).delay(0.9)) {
            wisp2Opacity = 0.85
        }
        withAnimation(.easeInOut(duration: 3.8).repeatForever(autoreverses: true).delay(0.9)) {
            wisp2Scale = 1.12
        }
        withAnimation(.easeInOut(duration: 4.1).repeatForever(autoreverses: true).delay(1.8)) {
            wisp3Offset = -20
        }
        withAnimation(.easeInOut(duration: 4.1).repeatForever(autoreverses: true).delay(1.8)) {
            wisp3Opacity = 0.70
        }
        withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true).delay(1.8)) {
            wisp3Scale = 1.1
        }
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            metalPulseScale = 1.12
        }
    }

    private func stopWisps() {
        wisp1Offset = 0; wisp1Opacity = 0; wisp1Scale = 1
        wisp2Offset = 0; wisp2Opacity = 0; wisp2Scale = 1
        wisp3Offset = 0; wisp3Opacity = 0; wisp3Scale = 1
        metalPulseScale = 1.0
    }

    private func nudgeAnimation() {
        let nudgeDist: CGFloat = -3
        withAnimation(.easeInOut(duration: 0.12).repeatCount(5, autoreverses: true)) {
            nudgeOffset = nudgeDist
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.1)) { nudgeOffset = 0 }
        }
    }

    private func flashAnimation() {
        withAnimation(.easeIn(duration: 0.1)) { flashOpacity = 0.6 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 1.5)) { flashOpacity = 0.0 }
        }
    }
}
