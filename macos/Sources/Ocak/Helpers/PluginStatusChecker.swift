import Foundation

/// Detects whether Ocak's Claude plugin is installed by reading ~/.claude/plugins/installed_plugins.json.
/// Does NOT rely on UserDefaults — reads the file to verify current state.
enum PluginStatusChecker {
    /// Returns true when the "ocak" plugin is registered in installed_plugins.json.
    /// Falls back to checking legacy OCAK_SESSION_ID hooks in settings.json.
    /// - Parameter installedPluginsPath: Override path for testing. Defaults to ~/.claude/plugins/installed_plugins.json.
    static func isInstalled(installedPluginsPath: String? = nil) -> Bool {
        let path = installedPluginsPath ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/plugins/installed_plugins.json").path

        guard let data = FileManager.default.contents(atPath: path),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let plugins = json["plugins"] as? [String: Any] else {
            return isLegacyInstalled()
        }

        return plugins.keys.contains { $0 == "ocak" || $0.hasPrefix("ocak@") }
    }

    /// Checks ~/.claude/settings.json for legacy OCAK_SESSION_ID hook entries.
    private static func isLegacyInstalled() -> Bool {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json").path
        guard let data = FileManager.default.contents(atPath: path),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let hooks = json["hooks"] as? [String: Any] else { return false }
        return hooks.values.contains { value in
            guard let matchers = value as? [[String: Any]] else { return false }
            return matchers.contains { matcher in
                guard let hookArray = matcher["hooks"] as? [[String: Any]] else { return false }
                return hookArray.contains { ($0["command"] as? String)?.contains("OCAK_SESSION_ID") == true }
            }
        }
    }
}
