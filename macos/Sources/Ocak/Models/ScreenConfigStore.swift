import Foundation
import AppKit
import Observation

/// Manages screen selection configuration for Ocak panels.
/// Stores selected screen identifiers and provides the active screen for ribbon/drawer placement.
@Observable
final class ScreenConfigStore {
    static let shared = ScreenConfigStore()

    private static let storageKey = "ocak.selectedScreenIDs"

    /// Persisted set of selected screen localizedName values.
    private(set) var selectedScreenNames: Set<String>

    var onChange: (() -> Void)?

    private init() {
        if let names = UserDefaults.standard.array(forKey: Self.storageKey) as? [String], !names.isEmpty {
            selectedScreenNames = Set(names)
        } else {
            // Default: all screens selected
            selectedScreenNames = Set(NSScreen.screens.map { $0.localizedName })
        }
    }

    /// Returns the screens that are both available and selected.
    var activeScreens: [NSScreen] {
        let available = NSScreen.screens
        let filtered = available.filter { selectedScreenNames.contains($0.localizedName) }
        return filtered.isEmpty ? available : filtered
    }

    /// The primary active screen (first selected, or first available if none selected).
    var primaryActiveScreen: NSScreen? {
        activeScreens.first
    }

    /// Whether a specific screen is in the active set.
    func isScreenActive(_ screen: NSScreen) -> Bool {
        selectedScreenNames.contains(screen.localizedName)
    }

    /// Toggle screen selection on/off.
    /// Prevents deselecting the last remaining screen.
    func toggleScreen(_ screen: NSScreen) {
        let name = screen.localizedName
        if selectedScreenNames.contains(name) {
            guard selectedScreenNames.count > 1 else { return }
            selectedScreenNames.remove(name)
        } else {
            selectedScreenNames.insert(name)
        }
        persist()
        onChange?()
    }

    /// Sync stored selection with currently available screens.
    /// Removes names of screens that no longer exist.
    func pruneDisconnectedScreens() {
        let available = Set(NSScreen.screens.map { $0.localizedName })
        let before = selectedScreenNames
        selectedScreenNames = selectedScreenNames.intersection(available)
        if selectedScreenNames != before {
            persist()
            onChange?()
        }
    }

    private func persist() {
        UserDefaults.standard.set(Array(selectedScreenNames), forKey: Self.storageKey)
    }
}
