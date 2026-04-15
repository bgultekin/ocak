import Foundation
import Observation
import AppKit

enum AppearanceMode: String, Codable, CaseIterable {
    case dark
    case light
    case auto

    var displayName: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        case .auto: return "Auto"
        }
    }
}

@Observable
final class AppearanceConfigStore {
    static let shared = AppearanceConfigStore()

    private static let storageKey = "ocak.appearanceMode"

    private(set) var mode: AppearanceMode
    var onChange: (() -> Void)?

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let mode = AppearanceMode(rawValue: raw) {
            self.mode = mode
        } else {
            self.mode = .auto
        }
    }

    var effectiveMode: AppearanceMode {
        switch mode {
        case .dark, .light:
            return mode
        case .auto:
            return effectiveSystemMode
        }
    }

    private var effectiveSystemMode: AppearanceMode {
        let appearance = NSApp.effectiveAppearance
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return .dark
        } else {
            return .light
        }
    }

    func setMode(_ newMode: AppearanceMode) {
        mode = newMode
        persist()
        onChange?()
    }

    private func persist() {
        UserDefaults.standard.set(mode.rawValue, forKey: Self.storageKey)
    }
}