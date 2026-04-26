import CoreGraphics
import Foundation
import Observation

enum HotkeyMode: String, Codable {
    case doubleTap
    case combination
}

enum DoubleTapModifier: String, Codable, CaseIterable {
    case command
    case option
    case control
    case shift

    var displayName: String {
        switch self {
        case .command: return "⌘ Command"
        case .option:  return "⌥ Option"
        case .control: return "⌃ Control"
        case .shift:   return "⇧ Shift"
        }
    }

    var cgEventFlag: CGEventFlags {
        switch self {
        case .command: return .maskCommand
        case .option:  return .maskAlternate
        case .control: return .maskControl
        case .shift:   return .maskShift
        }
    }
}

@Observable
final class HotkeyConfigStore {
    static let shared = HotkeyConfigStore()

    private static let modeKey      = "ocak.hotkeyMode"
    private static let modifierKey  = "ocak.doubleTapModifier"
    private static let thresholdKey = "ocak.doubleTapThresholdMs"

    private(set) var mode: HotkeyMode
    private(set) var doubleTapModifier: DoubleTapModifier
    private(set) var doubleTapThresholdMs: Int

    private init() {
        let ud = UserDefaults.standard
        mode = ud.string(forKey: Self.modeKey)
            .flatMap(HotkeyMode.init) ?? .combination
        doubleTapModifier = ud.string(forKey: Self.modifierKey)
            .flatMap(DoubleTapModifier.init) ?? .command
        let stored = ud.integer(forKey: Self.thresholdKey)
        doubleTapThresholdMs = stored > 0 ? stored : 300
    }

    func setMode(_ mode: HotkeyMode) {
        self.mode = mode
        persist()
    }

    func setDoubleTapModifier(_ modifier: DoubleTapModifier) {
        doubleTapModifier = modifier
        persist()
    }

    func setDoubleTapThresholdMs(_ ms: Int) {
        doubleTapThresholdMs = max(50, min(ms, 2000))
        persist()
    }

    private func persist() {
        let ud = UserDefaults.standard
        ud.set(mode.rawValue,              forKey: Self.modeKey)
        ud.set(doubleTapModifier.rawValue, forKey: Self.modifierKey)
        ud.set(doubleTapThresholdMs,       forKey: Self.thresholdKey)
    }
}
