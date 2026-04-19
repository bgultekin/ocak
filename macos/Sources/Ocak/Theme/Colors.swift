import SwiftUI
import AppKit

enum OcakTheme {
    // MARK: - Terminal backgrounds

    static var terminalBackground: Color {
        terminalEffectiveMode == .dark ? Color(hex: 0x0D0D10) : Color.white
    }

    static var terminalHeaderBg: Color {
        effectiveMode == .dark ? Color(hex: 0x1C1C1E) : Color(hex: 0xF5F5F7)
    }

    static var terminalDivider: Color {
        effectiveMode == .dark ? Color(hex: 0x2A2A2C) : Color(hex: 0xD1D1D6)
    }

    // MARK: - Card / surface

    static var cardBackground: Color {
        effectiveMode == .dark ? Color(hex: 0x242426) : Color(hex: 0xF5F5F7)
    }

    // oklch(0.75 0.165 45) ≈ sRGB(1.0, 0.530, 0.298) at 10% opacity (0.9 transparency)
    static let activeTint = Color(red: 1.0, green: 0.530, blue: 0.298).opacity(0.1)

    // oklch(0.75 0.165 45) ≈ sRGB(1.0, 0.530, 0.298)
    static let activeIconColor = Color(red: 1.0, green: 0.530, blue: 0.298)

    // oklch(0.75 0.165 45) ≈ sRGB(1.0, 0.530, 0.298) at 0.7 opacity
    static let activeBorder = Color(red: 1.0, green: 0.530, blue: 0.298).opacity(0.7)

    static var statusBlueBackground: Color {
        effectiveMode == .dark ? Color(hex: 0x0A84FF).opacity(0.1) : Color(hex: 0x0A84FF).opacity(0.08)
    }

    static var statusBlueBorder: Color {
        effectiveMode == .dark ? Color.clear : Color(hex: 0x0A84FF).opacity(0.3)
    }

    static var dropTargetBackground: Color {
        effectiveMode == .dark ? Color(hex: 0x0A84FF).opacity(0.15) : Color(hex: 0x0A84FF).opacity(0.12)
    }

    static var dropTargetBorder: Color {
        effectiveMode == .dark ? Color(hex: 0x0A84FF).opacity(0.5) : Color(hex: 0x0A84FF).opacity(0.4)
    }

    // MARK: - Status dots (same in both themes)

    static let statusBlue = Color(hex: 0x0A84FF)
    static let statusAmber = Color(hex: 0xFF9F0A)
    static let statusGreen = Color(hex: 0x30D158)
    static let statusGray = Color(nsColor: .tertiaryLabelColor)

    // MARK: - Session icons (AI tool type icons)

    static var sessionIconColor: Color {
        effectiveMode == .dark ? Color.white.opacity(0.73) : Color(hex: 0x1D1D1F).opacity(0.8)
    }

    // MARK: - Label hierarchy

    static var labelPrimary: Color {
        effectiveMode == .dark ? Color(hex: 0xEBEBF5) : Color(hex: 0x1D1D1F)
    }

    static var labelSecondary: Color {
        effectiveMode == .dark ? Color(hex: 0xEBEBF5, alpha: 0.38) : Color(hex: 0x1D1D1F, alpha: 0.6)
    }

    static var sectionLabel: Color {
        effectiveMode == .dark ? Color(hex: 0x636366) : Color(hex: 0x6C6C70)
    }

    static var sectionLabelHighlighted: Color {
        effectiveMode == .dark ? Color(hex: 0xAEAEB2) : Color(hex: 0x1C1C1E)
    }

    // MARK: - Button backgrounds

    static var buttonBackground: Color {
        effectiveMode == .dark ? Color(hex: 0x2A2A2C) : Color(hex: 0xE5E5EA)
    }

    static var inputBackground: Color {
        effectiveMode == .dark ? Color(hex: 0x3A3A3C) : Color(hex: 0xE5E5EA)
    }

    static var inputBorder: Color {
        effectiveMode == .dark ? Color.white.opacity(0.08) : Color(hex: 0xB8B8BC)
    }

    static var buttonHoverBackground: Color {
        effectiveMode == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    static var dragPreviewBackground: Color {
        effectiveMode == .dark ? Color(hex: 0x1E1E20) : Color(hex: 0x424244)
    }

    static var divider: Color {
        effectiveMode == .dark ? Color.white.opacity(0.04) : Color(hex: 0xC7C7CC)
    }

    // MARK: - System color helpers

    static let label = Color(nsColor: .labelColor)
    static let secondaryLabel = Color(nsColor: .secondaryLabelColor)
    static let tertiaryLabel = Color(nsColor: .tertiaryLabelColor)
    static let separator = Color(nsColor: .separatorColor)
    static let controlAccent = Color(nsColor: .controlAccentColor)
    static let control = Color(nsColor: .controlColor)

    // MARK: - Helpers

    private static var effectiveMode: AppearanceMode {
        AppearanceConfigStore.shared.effectiveMode
    }

    private static var terminalEffectiveMode: AppearanceMode {
        TerminalThemeConfigStore.shared.effectiveMode
    }

    static func statusColor(for status: SessionStatus) -> Color {
        switch status {
        case .new: return statusGray
        case .working: return statusBlue
        case .needs_input: return statusAmber
        case .done: return statusGreen
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}