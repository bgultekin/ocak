import SwiftUI

/// Persisted panel widths and terminal height per screen.
@Observable
final class PanelSizeStore {
    static let shared = PanelSizeStore()

    static let minSessionList: CGFloat = 240
    static let maxSessionList: CGFloat = 500
    static let minTerminal: CGFloat = 400
    static let maxTerminal: CGFloat = 1200
    static let defaultSessionList: CGFloat = 350
    static let defaultTerminal: CGFloat = 700
    static let minTerminalPaneHeight: CGFloat = 200
    /// Terminal pane max height is 90% of the screen's visible height (computed dynamically).
    static let maxTerminalPaneHeightFraction: CGFloat = 0.95

    /// Fixed chrome: terminal resize handle (6) + session-list resize handle (6) + gap (6)
    static let terminalChrome: CGFloat = 6 + 6 + 6
    /// Fixed chrome: session-list resize handle (6) + gap (6)
    static let sessionListChrome: CGFloat = 6 + 6

    private(set) var sessionListWidth: CGFloat = defaultSessionList
    private(set) var terminalWidth: CGFloat = defaultTerminal
    private(set) var terminalPaneHeight: CGFloat = 800
    var expandedWidth: CGFloat { sessionListWidth + terminalWidth + Self.terminalChrome }
    var collapsedWidth: CGFloat { sessionListWidth + Self.sessionListChrome }

    private init() { }

    /// Load saved sizes for a screen, falling back to defaults.
    func load(for screen: NSScreen) {
        let key = screenKey(for: screen)
        let maxHeight = screen.visibleFrame.height * Self.maxTerminalPaneHeightFraction
        if let all = UserDefaults.standard.dictionary(forKey: "ocak.panelSizes") as? [String: [String: Double]],
           let sizes = all[key] {
            sessionListWidth = CGFloat(sizes["sessionList"] ?? Self.defaultSessionList)
            terminalWidth = CGFloat(sizes["terminal"] ?? Self.defaultTerminal)
            if let savedHeight = sizes["terminalPaneHeight"] {
                terminalPaneHeight = min(maxHeight, max(Self.minTerminalPaneHeight, CGFloat(savedHeight)))
            } else {
                terminalPaneHeight = maxHeight
            }
        } else {
            sessionListWidth = Self.defaultSessionList
            terminalWidth = Self.defaultTerminal
            terminalPaneHeight = maxHeight
        }
    }

    /// Persist current sizes for the given screen.
    func save(for screen: NSScreen) {
        let key = screenKey(for: screen)
        var all = UserDefaults.standard.dictionary(forKey: "ocak.panelSizes") as? [String: [String: Double]] ?? [:]
        all[key] = [
            "sessionList": Double(sessionListWidth),
            "terminal": Double(terminalWidth),
            "terminalPaneHeight": Double(terminalPaneHeight),
        ]
        UserDefaults.standard.set(all, forKey: "ocak.panelSizes")
    }

    /// Update session list width with clamping and immediate persistence.
    func updateSessionListWidth(_ width: CGFloat, for screen: NSScreen) {
        sessionListWidth = min(Self.maxSessionList, max(Self.minSessionList, width))
        save(for: screen)
    }

    /// Update terminal width with clamping and immediate persistence.
    func updateTerminalWidth(_ width: CGFloat, for screen: NSScreen) {
        terminalWidth = min(Self.maxTerminal, max(Self.minTerminal, width))
        save(for: screen)
    }

    /// Update terminal pane height with clamping (max 90% of screen) and immediate persistence.
    func updateTerminalPaneHeight(_ height: CGFloat, for screen: NSScreen) {
        let maxHeight = screen.visibleFrame.height * Self.maxTerminalPaneHeightFraction
        terminalPaneHeight = min(maxHeight, max(Self.minTerminalPaneHeight, height))
        save(for: screen)
    }

    private func screenKey(for screen: NSScreen) -> String {
        "\(screen.localizedName)_\(Int(screen.frame.width))x\(Int(screen.frame.height))"
    }
}
