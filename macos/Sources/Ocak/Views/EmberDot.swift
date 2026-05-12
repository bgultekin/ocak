import SwiftUI

/// Animated circular status dot with Hearth ember/coal/sage palette.
struct EmberDot: View {
    let status: SessionStatus
    var size: CGFloat = 8
    var isMarked: Bool = false

    @State private var phase: Double = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var dotColor: Color {
        switch status {
        case .new:         return OcakTheme.coalDim
        case .working:     return OcakTheme.ember
        case .needs_input: return OcakTheme.awaiting
        case .done:        return OcakTheme.done
        }
    }

    private var glowColor: Color {
        switch status {
        case .working:     return OcakTheme.emberGlow
        case .needs_input: return OcakTheme.awaitingGlow
        case .done:        return OcakTheme.doneGlow
        default:           return .clear
        }
    }

    private var minOpacity: Double {
        switch status {
        case .working:     return 0.55
        case .needs_input: return 0.35
        default:           return 1.0
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(dotColor, lineWidth: 1.5)
                .frame(width: size + 10, height: size + 10)
                .brightness(0.2)
                .opacity(isMarked ? 1 : 0)
            Circle()
                .fill(dotColor)
                .frame(width: size, height: size)
                .shadow(color: glowColor, radius: 4)
                .shadow(color: glowColor.opacity(0.6), radius: 10)
                .opacity(reduceMotion ? 1.0 : phase)
        }
        .frame(width: size + 10, height: size + 10)
        .fixedSize()
        .onAppear { startAnimating() }
        .onChange(of: status) { _, _ in startAnimating() }
        .onChange(of: reduceMotion) { _, _ in startAnimating() }
        .onChange(of: isMarked) { _, _ in startAnimating() }
    }

    private func startAnimating() {
        phase = 1.0
        guard !reduceMotion else { return }
        switch status {
        case .working:
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                phase = minOpacity
            }
        case .needs_input:
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                phase = minOpacity
            }
        default:
            break
        }
    }
}
