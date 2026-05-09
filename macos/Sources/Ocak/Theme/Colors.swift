import SwiftUI
import AppKit

// MARK: - Hearth palette (always-dark, warm ember tones)

enum OcakTheme {

    // MARK: Card chrome
    static let cardBg        = Color(red: 22/255, green: 17/255, blue: 13/255).opacity(0.78)
    static let cardEdge      = Color(red: 1, green: 200/255, blue: 140/255).opacity(0.08)
    static let termBg        = Color(hex: 0x0E0A07)

    // MARK: Row
    static let rowHighlight  = Color(red: 48/255, green: 36/255, blue: 26/255).opacity(0.92)

    // MARK: Status (ember dots)
    static let ember         = Color(hex: 0xFF7A3A)
    static let emberGlow     = Color(hex: 0xFF7A3A).opacity(0.55)
    static let awaiting      = Color(hex: 0xFFC56E)
    static let awaitingGlow  = Color(hex: 0xFFC56E).opacity(0.48)
    static let done          = Color(hex: 0x9EC38A)
    static let doneGlow      = Color(hex: 0x9EC38A).opacity(0.32)
    static let coalDim       = Color(hex: 0x5A3A26)

    // MARK: Text hierarchy
    static let text          = Color(red: 243/255, green: 232/255, blue: 216/255)
    static let textDim       = Color(red: 243/255, green: 232/255, blue: 216/255).opacity(0.55)
    static let textFaint     = Color(red: 243/255, green: 232/255, blue: 216/255).opacity(0.32)
    static let textMuted     = Color(red: 243/255, green: 232/255, blue: 216/255).opacity(0.20)

    // MARK: Aliases (map to Hearth equivalents — keep these so call sites compile unchanged)
    static var terminalBackground: Color   { termBg }
    static var terminalHeaderBg: Color     { Color(hex: 0x0E0A07) }
    static var terminalDivider: Color      { cardEdge }
    static var cardBackground: Color       { cardBg }
    static let activeTint                  = rowHighlight
    static let activeIconColor             = ember
    static let activeBorder                = ember.opacity(0.7)
    static let warningIcon                 = Color.orange
    static var warningBackground: Color    { Color.orange.opacity(0.1) }
    static var statusBlueBackground: Color { ember.opacity(0.1) }
    static var statusBlueBorder: Color     { Color.clear }
    static var dropTargetBackground: Color { ember.opacity(0.15) }
    static var dropTargetBorder: Color     { ember.opacity(0.5) }
    static let statusBlue                  = ember
    static let statusAmber                 = awaiting
    static let statusGreen                 = done
    static var statusGray: Color           { coalDim }
    static var sessionIconColor: Color     { textDim }
    static var labelPrimary: Color         { text }
    static var labelSecondary: Color       { textDim }
    static var sectionLabel: Color         { textDim }
    static var sectionLabelHighlighted: Color { text }
    static let ctaBackground               = text.opacity(0.08)
    static var buttonBackground: Color     { Color(hex: 0x2A1C12).opacity(0.8) }
    static var inputBackground: Color      { Color(hex: 0x2A1C12).opacity(0.8) }
    static var inputBorder: Color          { cardEdge }
    static var buttonHoverBackground: Color { text.opacity(0.08) }
    static var dragPreviewBackground: Color { Color(hex: 0x2A1C12) }
    static var divider: Color              { cardEdge }
    static let label                       = text
    static let secondaryLabel              = textDim
    static let tertiaryLabel               = textFaint
    static let separator                   = cardEdge
    static let controlAccent               = ember
    static let control                     = cardBg

    static func statusColor(for status: SessionStatus) -> Color {
        switch status {
        case .new:          return coalDim
        case .working:      return ember
        case .needs_input:  return awaiting
        case .done:         return done
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
