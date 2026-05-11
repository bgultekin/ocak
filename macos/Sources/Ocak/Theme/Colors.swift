import SwiftUI
import AppKit

enum OcakTheme {

    // MARK: - Mode helpers

    private static var mode: AppearanceMode {
        AppearanceConfigStore.shared.effectiveMode
    }

    private static var terminalMode: AppearanceMode {
        TerminalThemeConfigStore.shared.effectiveMode
    }

    static var isHearth: Bool { mode == .hearth }
    static var isDark: Bool { mode == .dark }
    static var isLight: Bool { mode == .light }

    // MARK: - Card chrome

    static var cardBg: Color {
        if isHearth { return Color(red: 20/255, green: 17/255, blue: 13/255).opacity(0.78) }
        return isDark ? Color(hex: 0x242426) : Color(hex: 0xF5F5F7)
    }

    static var cardEdge: Color {
        if isHearth { return Color(red: 1, green: 200/255, blue: 140/255).opacity(0.08) }
        return isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }

    static var termBg: Color {
        if isHearth { return Color(hex: 0x0E0A07) }
        return isDark ? Color(hex: 0x1C1C1E) : Color(hex: 0xF5F5F7)
    }

    static var rowHighlight: Color {
        if isHearth { return Color(red: 48/255, green: 36/255, blue: 26/255).opacity(0.92) }
        return isDark
            ? Color(red: 1.0, green: 0.530, blue: 0.298).opacity(0.18)
            : Color(red: 1.0, green: 0.530, blue: 0.298).opacity(0.14)
    }

    // MARK: - Accent (ember / amber / sage / coal) — repurposed per theme

    static var ember: Color {
        if isHearth { return Color(hex: 0xFF7A3A) }
        return Color(hex: 0x0A84FF)
    }

    static var emberGlow: Color { ember.opacity(isHearth ? 0.55 : 0.4) }

    static var awaiting: Color {
        if isHearth { return Color(hex: 0xFFC56E) }
        return Color(hex: 0xFF9F0A)
    }

    static var awaitingGlow: Color { awaiting.opacity(isHearth ? 0.48 : 0.35) }

    static var done: Color {
        if isHearth { return Color(hex: 0x9EC38A) }
        return Color(hex: 0x30D158)
    }

    static var doneGlow: Color { done.opacity(isHearth ? 0.32 : 0.28) }

    static var coalDim: Color {
        if isHearth { return Color(hex: 0x5A3A26) }
        return isDark ? Color(hex: 0x636366) : Color(hex: 0xAEAEB2)
    }

    // MARK: - Text hierarchy

    static var text: Color {
        if isHearth { return Color(red: 243/255, green: 232/255, blue: 216/255) }
        return isDark ? Color(hex: 0xEBEBF5) : Color(hex: 0x1D1D1F)
    }

    static var textDim: Color {
        if isHearth { return Color(red: 243/255, green: 232/255, blue: 216/255).opacity(0.55) }
        return isDark ? Color(hex: 0xEBEBF5, alpha: 0.55) : Color(hex: 0x1D1D1F, alpha: 0.6)
    }

    static var textFaint: Color {
        if isHearth { return Color(red: 243/255, green: 232/255, blue: 216/255).opacity(0.32) }
        return isDark ? Color(hex: 0xEBEBF5, alpha: 0.32) : Color(hex: 0x1D1D1F, alpha: 0.42)
    }

    static var textMuted: Color {
        if isHearth { return Color(red: 243/255, green: 232/255, blue: 216/255).opacity(0.20) }
        return isDark ? Color(hex: 0xEBEBF5, alpha: 0.22) : Color(hex: 0x1D1D1F, alpha: 0.30)
    }

    // MARK: - Surfaces

    static var terminalBackground: Color {
        switch terminalMode {
        case .dark, .hearth: return Color(hex: 0x0D0D10)
        case .light:         return Color.white
        }
    }

    static var terminalHeaderBg: Color {
        if isHearth { return Color(hex: 0x0E0A07) }
        return isDark ? Color(hex: 0x1C1C1E) : Color(hex: 0xF5F5F7)
    }

    static var terminalDivider: Color {
        if isHearth { return cardEdge }
        return isDark ? Color(hex: 0x2A2A2C) : Color(hex: 0xD1D1D6)
    }

    static var cardBackground: Color { cardBg }

    // MARK: - Accent (selection / drop targets)

    static var activeTint: Color  { rowHighlight }
    static var activeIconColor: Color { ember }
    static var activeBorder: Color    { ember.opacity(0.7) }

    static let warningIcon = Color.orange

    static var warningBackground: Color {
        Color.orange.opacity(isHearth ? 0.10 : (isDark ? 0.10 : 0.08))
    }

    static var statusBlueBackground: Color { ember.opacity(0.10) }

    static var statusBlueBorder: Color {
        isLight ? ember.opacity(0.3) : Color.clear
    }

    static var dropTargetBackground: Color {
        ember.opacity(isHearth ? 0.15 : (isDark ? 0.15 : 0.12))
    }

    static var dropTargetBorder: Color {
        ember.opacity(isHearth ? 0.5 : (isDark ? 0.5 : 0.4))
    }

    // MARK: - Status dots

    static var statusBlue: Color  { ember }
    static var statusAmber: Color { awaiting }
    static var statusGreen: Color { done }
    static var statusGray: Color  { coalDim }

    // MARK: - Icons / labels

    static var sessionIconColor: Color {
        if isHearth { return textDim }
        return isDark ? Color.white.opacity(0.73) : Color(hex: 0x1D1D1F).opacity(0.8)
    }

    static var labelPrimary: Color   { text }
    static var labelSecondary: Color { textDim }

    static var sectionLabel: Color {
        if isHearth { return textDim }
        return isDark ? Color(hex: 0x636366) : Color(hex: 0x6C6C70)
    }

    static var sectionLabelHighlighted: Color {
        if isHearth { return text }
        return isDark ? Color(hex: 0xAEAEB2) : Color(hex: 0x1C1C1E)
    }

    // MARK: - CTA / buttons / inputs

    static var ctaBackground: Color {
        isHearth ? text.opacity(0.08) : Color.primary.opacity(0.08)
    }

    static var buttonBackground: Color {
        if isHearth { return Color(hex: 0x2A1C12).opacity(0.8) }
        return isDark ? Color(hex: 0x2A2A2C) : Color(hex: 0xE5E5EA)
    }

    static var inputBackground: Color {
        if isHearth { return Color(hex: 0x2A1C12).opacity(0.8) }
        return isDark ? Color(hex: 0x3A3A3C) : Color(hex: 0xE5E5EA)
    }

    static var inputBorder: Color {
        if isHearth { return cardEdge }
        return isDark ? Color.white.opacity(0.08) : Color(hex: 0xB8B8BC)
    }

    static var buttonHoverBackground: Color {
        if isHearth { return text.opacity(0.08) }
        return isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    static var dragPreviewBackground: Color {
        if isHearth { return Color(hex: 0x2A1C12) }
        return isDark ? Color(hex: 0x1E1E20) : Color(hex: 0x424244)
    }

    static var divider: Color {
        if isHearth { return cardEdge }
        return isDark ? Color.white.opacity(0.04) : Color(hex: 0xC7C7CC)
    }

    // MARK: - System color helpers

    static var label: Color          { text }
    static var secondaryLabel: Color { textDim }
    static var tertiaryLabel: Color  { textFaint }
    static var separator: Color {
        isHearth ? cardEdge : Color(nsColor: .separatorColor)
    }
    static var controlAccent: Color  { ember }
    static var control: Color        { cardBg }

    // MARK: - Hearth window backgrounds

    static let hearthBackground        = Color(hex: 0x0C0A08)
    static let hearthSidebarBackground = Color(hex: 0x100D0A)

    // MARK: - Flame icon gradient (app header, always warm fire colors)

    static let flameGradientStart = Color(hex: 0xFFD28A)
    static let flameGradientMid   = Color(hex: 0xFF7A3A)
    static let flameGradientEnd   = Color(hex: 0xC9492A)
    static let flameShadow        = Color(hex: 0xFF7A3A).opacity(0.55)

    // MARK: - Selected terminal row (always Hearth ember, across all themes)

    static let selectionBorder = Color(hex: 0xFF7A3A)
    static let selectionGlow   = Color(hex: 0xFF7A3A).opacity(0.55)

    // MARK: - Card-header warm gradient (Hearth only; Dark/Light get no overlay)

    static var cardHeaderOverlay: Color {
        isHearth ? Color(red: 1, green: 150/255, blue: 80/255).opacity(0.04) : Color.clear
    }

    // MARK: - Visual-effect material appearance (for HearthCard)

    static var visualEffectAppearance: NSAppearance? {
        switch mode {
        case .hearth, .dark: return NSAppearance(named: .vibrantDark)
        case .light:         return NSAppearance(named: .vibrantLight)
        }
    }

    // MARK: - Status helper

    static func statusColor(for status: SessionStatus) -> Color {
        switch status {
        case .new:         return coalDim
        case .working:     return ember
        case .needs_input: return awaiting
        case .done:        return done
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8)  & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
