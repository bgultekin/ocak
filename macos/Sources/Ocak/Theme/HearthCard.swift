import AppKit
import SwiftUI

private struct ThemedVisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        v.appearance = OcakTheme.visualEffectAppearance
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.appearance = OcakTheme.visualEffectAppearance
    }
}

struct HearthCardModifier: ViewModifier {
    var radius: CGFloat = 14
    var overrideBg: Color?
    var shadowRadius: CGFloat = 15

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    ThemedVisualEffectView()
                    (overrideBg ?? OcakTheme.cardBg)
                }
                .clipShape(RoundedRectangle(cornerRadius: radius))
            )
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .shadow(color: .black.opacity(OcakTheme.isLight ? 0.10 : 0.30),
                    radius: shadowRadius, x: 0, y: shadowRadius * 0.72)
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(OcakTheme.cardEdge, lineWidth: 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius)
                            .inset(by: 0.5)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        OcakTheme.cardEdge.opacity(1.25),
                                        Color.clear,
                                    ],
                                    startPoint: .top,
                                    endPoint: UnitPoint(x: 0.5, y: 0.25)
                                ),
                                lineWidth: 1
                            )
                    )
            )
    }
}

extension View {
    func hearthCard(radius: CGFloat = 14, overrideBg: Color? = nil, shadowRadius: CGFloat = 25) -> some View {
        modifier(HearthCardModifier(radius: radius, overrideBg: overrideBg, shadowRadius: shadowRadius))
    }
}
