import Foundation
import Observation

@Observable
final class TriggerConfigStore {
    static let shared = TriggerConfigStore()

    private static let hoverKey  = "ocak.triggerHoverEnabled"
    private static let hotkeyKey = "ocak.triggerHotkeyEnabled"

    private(set) var hoverEnabled: Bool
    private(set) var hotkeyEnabled: Bool

    private init() {
        let ud = UserDefaults.standard
        let storedHover  = ud.object(forKey: Self.hoverKey)  as? Bool ?? true
        let storedHotkey = ud.object(forKey: Self.hotkeyKey) as? Bool ?? true
        if !storedHover && !storedHotkey {
            hoverEnabled  = true
            hotkeyEnabled = true
        } else {
            hoverEnabled  = storedHover
            hotkeyEnabled = storedHotkey
        }
    }

    func setHoverEnabled(_ enabled: Bool) {
        guard enabled || hotkeyEnabled else { return }
        hoverEnabled = enabled
        persist()
    }

    func setHotkeyEnabled(_ enabled: Bool) {
        guard enabled || hoverEnabled else { return }
        hotkeyEnabled = enabled
        persist()
    }

    private func persist() {
        let ud = UserDefaults.standard
        ud.set(hoverEnabled,  forKey: Self.hoverKey)
        ud.set(hotkeyEnabled, forKey: Self.hotkeyKey)
    }
}
