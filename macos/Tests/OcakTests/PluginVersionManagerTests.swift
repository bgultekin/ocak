import Testing
import Foundation

// Local copy for testing (cannot import executable target)
private enum PluginVersionManager {
    enum VersionError: Error {
        case readFailed
    }

    static func extractVersion(from data: Data) throws -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = json["version"] as? String else {
            return nil
        }
        return version
    }

    static func isVersionGreater(_ version1: String, than version2: String) -> Bool {
        let parts1 = version1.split(separator: ".").compactMap { Int($0) }
        let parts2 = version2.split(separator: ".").compactMap { Int($0) }
        guard parts1.count >= 3 && parts2.count >= 3 else { return false }
        if parts1[0] != parts2[0] { return parts1[0] > parts2[0] }
        if parts1[1] != parts2[1] { return parts1[1] > parts2[1] }
        return parts1[2] > parts2[2]
    }

    static func extractVersionFromJS(_ content: String) -> String? {
        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("// version:") {
                return trimmed.dropFirst("// version:".count).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    static func readBundledPluginVersion(pluginJSONPath: String) throws -> String? {
        let data = try Data(contentsOf: URL(fileURLWithPath: pluginJSONPath))
        return try extractVersion(from: data)
    }

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

@Suite("Plugin Version Manager")
struct PluginVersionManagerTests {

    // MARK: - extractVersion

    @Test("Extracts version from plugin.json data")
    func extractsBundledVersion() throws {
        let json = """
        {
          "name": "ocak",
          "version": "1.2.0",
          "description": "Test plugin"
        }
        """
        let data = json.data(using: .utf8)!
        let version = try PluginVersionManager.extractVersion(from: data)
        #expect(version == "1.2.0")
    }

    @Test("Returns nil for invalid JSON")
    func returnsNilForInvalidJSON() throws {
        let json = "not valid json {{{"
        let data = json.data(using: .utf8)!
        let version = try PluginVersionManager.extractVersion(from: data)
        #expect(version == nil)
    }

    @Test("Returns nil when version field missing")
    func returnsNilWhenVersionMissing() throws {
        let json = """
        {
          "name": "ocak",
          "description": "Test plugin"
        }
        """
        let data = json.data(using: .utf8)!
        let version = try PluginVersionManager.extractVersion(from: data)
        #expect(version == nil)
    }

    // MARK: - isVersionGreater

    @Test("Compares versions correctly")
    func comparesVersionsCorrectly() {
        #expect(PluginVersionManager.isVersionGreater("1.2.0", than: "1.1.0") == true)
        #expect(PluginVersionManager.isVersionGreater("2.0.0", than: "1.9.9") == true)
        #expect(PluginVersionManager.isVersionGreater("1.0.5", than: "1.0.4") == true)
        #expect(PluginVersionManager.isVersionGreater("1.0.0", than: "1.0.0") == false)
        #expect(PluginVersionManager.isVersionGreater("1.0.0", than: "1.0.1") == false)
        #expect(PluginVersionManager.isVersionGreater("0.9.0", than: "1.0.0") == false)
    }

    @Test("Handles invalid version strings in comparison")
    func handlesInvalidVersionStrings() {
        #expect(PluginVersionManager.isVersionGreater("invalid", than: "1.0.0") == false)
        #expect(PluginVersionManager.isVersionGreater("1.0.0", than: "invalid") == false)
        #expect(PluginVersionManager.isVersionGreater("", than: "1.0.0") == false)
    }

    // MARK: - readBundledPluginVersion

    @Test("Reads bundled plugin version from bundle resources")
    func readsBundledPluginVersion() throws {
        let thisFile = URL(fileURLWithPath: #filePath)
        let packageRoot = thisFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pluginJSONPath = packageRoot
            .appendingPathComponent("Sources/Ocak/Resources/claude-ocak-marketplace/plugins/ocak/.claude-plugin/plugin.json")
            .path
        let version = try PluginVersionManager.readBundledPluginVersion(pluginJSONPath: pluginJSONPath)
        #expect(version != nil)
        #expect(version != "")
    }

    // MARK: - readInstalledPluginVersion

    @Test("Reads installed plugin version from installed_plugins.json")
    func readsInstalledPluginVersion() throws {
        let json = """
        {
          "version": 2,
          "plugins": {
            "ocak@ocak-plugins": [
              {
                "scope": "user",
                "installPath": "/Users/test/.ocak/plugin",
                "version": "1.1.0"
              }
            ]
          }
        }
        """
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let filePath = dir.appendingPathComponent("installed_plugins.json").path
        try json.write(toFile: filePath, atomically: true, encoding: .utf8)

        let version = try PluginVersionManager.readInstalledPluginVersion(installedPluginsPath: filePath)
        #expect(version == "1.1.0")
    }

    @Test("Returns nil when plugin not found in installed_plugins.json")
    func returnsNilWhenPluginNotFound() throws {
        let json = """
        {
          "version": 2,
          "plugins": {
            "other-plugin": [{"scope": "user", "installPath": "/some/path", "version": "1.0.0"}]
          }
        }
        """
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let filePath = dir.appendingPathComponent("installed_plugins.json").path
        try json.write(toFile: filePath, atomically: true, encoding: .utf8)

        let version = try PluginVersionManager.readInstalledPluginVersion(installedPluginsPath: filePath)
        #expect(version == nil)
    }

    @Test("Returns nil when installed_plugins.json missing")
    func returnsNilWhenFileMissing() throws {
        let nonexistentPath = "/tmp/nonexistent-\(UUID().uuidString)/installed_plugins.json"
        let version = try PluginVersionManager.readInstalledPluginVersion(installedPluginsPath: nonexistentPath)
        #expect(version == nil)
    }

    // MARK: - extractVersionFromJS

    @Test("Extracts version from JS comment")
    func extractsVersionFromJS() {
        let js = """
        // Ocak plugin for OpenCode
        // version: 1.2.3
        const x = 1
        """
        #expect(PluginVersionManager.extractVersionFromJS(js) == "1.2.3")
    }

    @Test("Returns nil when no version comment in JS")
    func returnsNilWhenNoVersionComment() {
        let js = "// no version here\nconst x = 1"
        #expect(PluginVersionManager.extractVersionFromJS(js) == nil)
    }

    @Test("Extracts version from bundled plugin.js")
    func extractsVersionFromBundledPluginJS() throws {
        let thisFile = URL(fileURLWithPath: #filePath)
        let packageRoot = thisFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pluginJSPath = packageRoot
            .appendingPathComponent("Sources/Ocak/Resources/opencode-ocak/plugin.js")
            .path
        let content = try String(contentsOfFile: pluginJSPath, encoding: .utf8)
        let version = PluginVersionManager.extractVersionFromJS(content)
        #expect(version != nil)
        #expect(version != "")
    }
}
