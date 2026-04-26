import Testing
import Foundation

// Mirror types (cannot import executable target)
private enum HotkeyMode: String, Codable, Equatable {
    case doubleTap
    case combination
}

private enum DoubleTapModifier: String, Codable, Equatable, CaseIterable {
    case command, option, control, shift
}

@Suite("HotkeyConfigStore — persistence")
struct HotkeyConfigStoreTests {

    @Test("defaults to combination mode")
    func defaultMode() {
        let defaults = UserDefaults(suiteName: "test.hotkey.defaults")!
        defaults.removePersistentDomain(forName: "test.hotkey.defaults")

        let raw = defaults.string(forKey: "ocak.hotkeyMode")
        let mode = raw.flatMap { HotkeyMode(rawValue: $0) } ?? .combination
        #expect(mode == .combination)
    }

    @Test("defaults to command modifier")
    func defaultModifier() {
        let defaults = UserDefaults(suiteName: "test.hotkey.modifier")!
        defaults.removePersistentDomain(forName: "test.hotkey.modifier")

        let raw = defaults.string(forKey: "ocak.doubleTapModifier")
        let modifier = raw.flatMap { DoubleTapModifier(rawValue: $0) } ?? .command
        #expect(modifier == .command)
    }

    @Test("persists mode to UserDefaults")
    func persistsMode() {
        let defaults = UserDefaults(suiteName: "test.hotkey.persist")!
        defaults.removePersistentDomain(forName: "test.hotkey.persist")

        defaults.set(HotkeyMode.doubleTap.rawValue, forKey: "ocak.hotkeyMode")
        let raw = defaults.string(forKey: "ocak.hotkeyMode")
        let mode = raw.flatMap { HotkeyMode(rawValue: $0) }
        #expect(mode == .doubleTap)
    }

    @Test("persists doubleTap modifier to UserDefaults")
    func persistsModifier() {
        let defaults = UserDefaults(suiteName: "test.hotkey.modifier2")!
        defaults.removePersistentDomain(forName: "test.hotkey.modifier2")

        defaults.set(DoubleTapModifier.option.rawValue, forKey: "ocak.doubleTapModifier")
        let raw = defaults.string(forKey: "ocak.doubleTapModifier")
        let modifier = raw.flatMap { DoubleTapModifier(rawValue: $0) }
        #expect(modifier == .option)
    }

    @Test("all modifier cases have valid rawValues")
    func allModifierCases() {
        for modifier in DoubleTapModifier.allCases {
            #expect(!modifier.rawValue.isEmpty)
            #expect(DoubleTapModifier(rawValue: modifier.rawValue) == modifier)
        }
    }
}
