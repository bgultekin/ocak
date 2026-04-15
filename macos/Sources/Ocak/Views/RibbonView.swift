import SwiftUI

/// The 5px-wide edge ribbon that communicates aggregate session status.
struct RibbonView: View {
    let store: SessionStore

    @State private var breatheOpacity: Double = 0.15
    @State private var nudgeOffset: CGFloat = 0
    @State private var flashOpacity: Double = 0
    @State private var previousHasAttention = false

    private var ribbonState: RibbonState {
        if store.hasAttention { return .attention }
        if store.showSuccessFlash { return .success }
        if store.hasDone { return .done }
        if store.hasWorking { return .processing }
        return .idle
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(ribbonColor)
            .opacity(ribbonOpacity)
            .frame(width: 5)
            .offset(x: nudgeOffset)
            .onChange(of: ribbonState) { oldState, newState in
                handleStateTransition(from: oldState, to: newState)
            }
            .onAppear {
                if ribbonState == .processing {
                    startBreathing()
                }
            }
    }

    private var ribbonColor: Color {
        switch ribbonState {
        case .idle: return .gray
        case .processing: return OcakTheme.statusBlue
        case .done: return OcakTheme.statusGreen
        case .attention: return OcakTheme.statusAmber
        case .success: return OcakTheme.statusGreen
        }
    }

    private var ribbonOpacity: Double {
        switch ribbonState {
        case .idle: return 0.3
        case .processing: return breatheOpacity
        case .done: return 0.5
        case .attention: return 0.7
        case .success: return flashOpacity
        }
    }

    private func handleStateTransition(from oldState: RibbonState, to newState: RibbonState) {
        switch newState {
        case .processing:
            startBreathing()
        case .attention:
            nudgeAnimation()
        case .success:
            flashAnimation()
        case .done, .idle:
            breatheOpacity = 0.15
            nudgeOffset = 0
        }
    }

    private func startBreathing() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            breatheOpacity = 0.35
        }
    }

    private func nudgeAnimation() {
        let nudgeDist: CGFloat = -3
        withAnimation(.easeInOut(duration: 0.12).repeatCount(5, autoreverses: true)) {
            nudgeOffset = nudgeDist
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.1)) {
                nudgeOffset = 0
            }
        }
    }

    private func flashAnimation() {
        withAnimation(.easeIn(duration: 0.1)) {
            flashOpacity = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 1.5)) {
                flashOpacity = 0.0
            }
        }
    }
}

private enum RibbonState {
    case idle, processing, done, attention, success
}
