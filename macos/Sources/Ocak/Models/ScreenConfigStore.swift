import Foundation
import AppKit
import Observation

/// Manages screen selection configuration for Ocak panels.
/// Stores selected screen identifiers and provides the active screen for ribbon/drawer placement.
@Observable
final class ScreenConfigStore {
    static let shared = ScreenConfigStore()

    private static let storageKey = "ocak.selectedScreenIDs"
    private static let edgeStorageKey = "ocak.panelEdges"
    private static let lastDrawerScreenKey = "ocak.lastDrawerScreen"

    /// Persisted set of selected screen localizedName values.
    private(set) var selectedScreenNames: Set<String>
    /// In-memory cache of per-screen edge config, keyed by screen localizedName.
    private var panelEdgeCache: [String: PanelEdge]

    var onChange: (() -> Void)?

    private init() {
        if let names = UserDefaults.standard.array(forKey: Self.storageKey) as? [String], !names.isEmpty {
            selectedScreenNames = Set(names)
        } else {
            selectedScreenNames = Set(NSScreen.screens.map { $0.stableKey })
        }
        let stored = UserDefaults.standard.dictionary(forKey: Self.edgeStorageKey) as? [String: String] ?? [:]
        panelEdgeCache = stored.compactMapValues { PanelEdge(rawValue: $0) }
    }

    /// Returns the screens that are both available and selected.
    var activeScreens: [NSScreen] {
        let available = NSScreen.screens
        let filtered = available.filter { selectedScreenNames.contains($0.stableKey) }
        return filtered.isEmpty ? available : filtered
    }

    /// The primary active screen (first selected, or first available if none selected).
    var primaryActiveScreen: NSScreen? {
        activeScreens.first
    }

    /// The last screen on which the drawer was shown, if it's still connected and active.
    var lastDrawerScreen: NSScreen? {
        guard let key = UserDefaults.standard.string(forKey: Self.lastDrawerScreenKey) else { return nil }
        return activeScreens.first { $0.stableKey == key }
    }

    func saveLastDrawerScreen(_ screen: NSScreen) {
        UserDefaults.standard.set(screen.stableKey, forKey: Self.lastDrawerScreenKey)
    }

    /// Whether a specific screen is in the active set.
    func isScreenActive(_ screen: NSScreen) -> Bool {
        selectedScreenNames.contains(screen.stableKey)
    }

    /// Toggle screen selection on/off.
    /// Prevents deselecting the last remaining screen.
    func toggleScreen(_ screen: NSScreen) {
        let key = screen.stableKey
        if selectedScreenNames.contains(key) {
            guard selectedScreenNames.count > 1 else { return }
            selectedScreenNames.remove(key)
        } else {
            selectedScreenNames.insert(key)
        }
        persist()
        onChange?()
    }

    /// Sync stored selection with currently available screens.
    /// Removes keys of screens that no longer exist.
    func pruneDisconnectedScreens() {
        let available = Set(NSScreen.screens.map { $0.stableKey })
        let before = selectedScreenNames
        selectedScreenNames = selectedScreenNames.intersection(available)
        if selectedScreenNames != before {
            persist()
            onChange?()
        }
    }

    /// Returns the configured panel edge for a screen (defaults to .right).
    func panelEdge(for screen: NSScreen) -> PanelEdge {
        panelEdgeCache[screen.stableKey] ?? .right
    }

    /// Persist a new panel edge for a screen and trigger ribbon rebuild.
    func setPanelEdge(_ edge: PanelEdge, for screen: NSScreen) {
        let key = screen.stableKey
        panelEdgeCache[key] = edge
        var all = UserDefaults.standard.dictionary(forKey: Self.edgeStorageKey) as? [String: String] ?? [:]
        all[key] = edge.rawValue
        UserDefaults.standard.set(all, forKey: Self.edgeStorageKey)
        onChange?()
    }

    private func persist() {
        UserDefaults.standard.set(Array(selectedScreenNames), forKey: Self.storageKey)
    }
}
