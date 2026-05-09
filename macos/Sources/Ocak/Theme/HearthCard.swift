import AppKit
import SwiftUI

// MARK: - Warm frosted-glass backing

private struct WarmVisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        v.appearance = NSAppearance(named: .vibrantDark)
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Card chrome modifier

struct HearthCardModifier: ViewModifier {
    var radius: CGFloat = 14
    var overrideBg: Color?

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    WarmVisualEffectView()
                    (overrideBg ?? Color(red: 22/255, green: 17/255, blue: 13/255).opacity(0.78))
                }
                .clipShape(RoundedRectangle(cornerRadius: radius))
            )
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .shadow(color: .black.opacity(0.55), radius: 25, x: 0, y: 18)
            .shadow(color: Color(red: 1, green: 200/255, blue: 140/255).opacity(0.08), radius: 0, x: 0, y: 0)
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(Color(red: 1, green: 200/255, blue: 140/255).opacity(0.08), lineWidth: 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius)
                            .inset(by: 0.5)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1, green: 200/255, blue: 140/255).opacity(0.10),
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
    func hearthCard(radius: CGFloat = 14, overrideBg: Color? = nil) -> some View {
        modifier(HearthCardModifier(radius: radius, overrideBg: overrideBg))
    }
}
