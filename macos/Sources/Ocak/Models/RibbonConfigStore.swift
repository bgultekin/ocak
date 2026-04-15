import Foundation
import Observation

enum RibbonStyle: String, Codable, CaseIterable {
    case solid
    case smoke
    case invisible
    case none

    var displayName: String {
        switch self {
        case .solid: return "Solid"
        case .smoke: return "Smoke"
        case .invisible: return "Invisible"
        case .none: return "None"
        }
    }
}

@Observable
final class RibbonConfigStore {
    static let shared = RibbonConfigStore()

    private static let storageKey = "ocak.ribbonStyle"

    private(set) var ribbonStyle: RibbonStyle
    var onChange: (() -> Void)?

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let style = RibbonStyle(rawValue: raw) {
            ribbonStyle = style
        } else {
            ribbonStyle = .solid
        }
    }

    func setStyle(_ style: RibbonStyle) {
        ribbonStyle = style
        persist()
        onChange?()
    }

    private func persist() {
        UserDefaults.standard.set(ribbonStyle.rawValue, forKey: Self.storageKey)
    }
}
