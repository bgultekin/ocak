import Foundation
import Observation
import AppKit

enum TerminalThemeMode: String, Codable, CaseIterable {
    case dark
    case light
    case system

    var displayName: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        case .system: return "System Default"
        }
    }
}

@Observable
final class TerminalThemeConfigStore {
    static let shared = TerminalThemeConfigStore()

    private static let storageKey = "ocak.terminalThemeMode"

    private(set) var mode: TerminalThemeMode
    var onChange: (() -> Void)?

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let mode = TerminalThemeMode(rawValue: raw) {
            self.mode = mode
        } else {
            self.mode = .system
        }
    }

    var effectiveMode: AppearanceMode {
        switch mode {
        case .dark: return .dark
        case .light: return .light
        case .system: return systemMode
        }
    }

    private var systemMode: AppearanceMode {
        let appearance = NSApp.effectiveAppearance
        return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
    }

    func setMode(_ newMode: TerminalThemeMode) {
        mode = newMode
        persist()
        onChange?()
    }

    private func persist() {
        UserDefaults.standard.set(mode.rawValue, forKey: Self.storageKey)
    }
}
