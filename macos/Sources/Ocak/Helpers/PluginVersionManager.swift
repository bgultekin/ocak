import Foundation

enum PluginVersionManager {
    enum VersionError: Error {
        case readFailed
    }

    /// Extracts the version string from plugin.json data. Returns nil for missing or malformed data.
    static func extractVersion(from data: Data) throws -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = json["version"] as? String else {
            return nil
        }
        return version
    }

    /// Returns true if version1 is semantically greater than version2. Returns false for invalid inputs.
    static func isVersionGreater(_ version1: String, than version2: String) -> Bool {
        let parts1 = version1.split(separator: ".").compactMap { Int($0) }
        let parts2 = version2.split(separator: ".").compactMap { Int($0) }
        guard parts1.count >= 3 && parts2.count >= 3 else { return false }
        if parts1[0] != parts2[0] { return parts1[0] > parts2[0] }
        if parts1[1] != parts2[1] { return parts1[1] > parts2[1] }
        return parts1[2] > parts2[2]
    }

    /// Reads the version from the bundled plugin.json in app resources.
    /// Accepts an optional path override for testability.
    static func readBundledPluginVersion(pluginJSONPath: String? = nil) throws -> String? {
        let url: URL
        if let path = pluginJSONPath {
            url = URL(fileURLWithPath: path)
        } else {
            guard let pluginURL = Bundle.module.resourceURL?
                .appendingPathComponent("claude-ocak-marketplace/plugins/ocak/.claude-plugin/plugin.json"),
                  FileManager.default.fileExists(atPath: pluginURL.path) else {
                throw VersionError.readFailed
            }
            url = pluginURL
        }
        let data = try Data(contentsOf: url)
        return try extractVersion(from: data)
    }

    /// Extracts the version from a JS plugin file by scanning for a `// version: x.y.z` comment.
    static func extractVersionFromJS(_ content: String) -> String? {
        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("// version:") {
                return trimmed.dropFirst("// version:".count).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    /// Reads the version from the bundled OpenCode plugin.js in app resources.
    static func readBundledOpenCodeVersion(pluginJSPath: String? = nil) throws -> String? {
        let url: URL
        if let path = pluginJSPath {
            url = URL(fileURLWithPath: path)
        } else {
            guard let pluginURL = Bundle.module.resourceURL?
                .appendingPathComponent("opencode-ocak/plugin.js"),
                  FileManager.default.fileExists(atPath: pluginURL.path) else {
                throw VersionError.readFailed
            }
            url = pluginURL
        }
        let content = try String(contentsOf: url, encoding: .utf8)
        return extractVersionFromJS(content)
    }

    /// Reads the version from the installed OpenCode plugin at ~/.config/opencode/plugins/ocak.js.
    static func readInstalledOpenCodeVersion(installedPluginPath: String? = nil) -> String? {
        let path = installedPluginPath ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/opencode/plugins/ocak.js").path
        guard FileManager.default.fileExists(atPath: path),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }
        return extractVersionFromJS(content)
    }

    /// Reads the version of the installed ocak plugin from installed_plugins.json.
    /// Returns nil if plugin not found or file doesn't exist.
    static func readInstalledPluginVersion(installedPluginsPath: String? = nil) throws -> String? {
        let path = installedPluginsPath ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/plugins/installed_plugins.json").path

        guard FileManager.default.fileExists(atPath: path),
              let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let plugins = json["plugins"] as? [String: Any] else {
            return nil
        }

        let ocakKey = plugins.keys.first { $0 == "ocak" || $0 == "ocak@ocak-plugins" || $0.hasPrefix("ocak@") }
        guard let key = ocakKey,
              let pluginArray = plugins[key] as? [[String: Any]],
              let firstEntry = pluginArray.first,
              let version = firstEntry["version"] as? String else {
            return nil
        }
        return version
    }
}
