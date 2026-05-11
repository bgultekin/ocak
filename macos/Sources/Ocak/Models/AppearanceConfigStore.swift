import Foundation
import Observation
import AppKit

enum AppearanceMode: String, Codable, CaseIterable {
    case hearth
    case dark
    case light

    var displayName: String {
        switch self {
        case .hearth: return "Hearth"
        case .dark: return "Dark"
        case .light: return "Light"
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
            self.mode = .hearth
        }
    }

    var effectiveMode: AppearanceMode { mode }

    func setMode(_ newMode: AppearanceMode) {
        mode = newMode
        persist()
        onChange?()
    }

    private func persist() {
        UserDefaults.standard.set(mode.rawValue, forKey: Self.storageKey)
    }
}