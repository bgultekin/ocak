import Testing
import Foundation

// Local copy for testing — Swift 5.9 executable targets cannot be imported by test targets
private enum PluginStatusChecker {
    static func isInstalled(installedPluginsPath: String? = nil) -> Bool {
        let path = installedPluginsPath ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/plugins/installed_plugins.json").path

        guard let data = FileManager.default.contents(atPath: path),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let plugins = json["plugins"] as? [String: Any] else {
            return false
        }

        return plugins.keys.contains { $0 == "ocak" || $0.hasPrefix("ocak@") }
    }
}

@Suite("Plugin Status Checker — SETTINGS-01")
struct PluginStatusCheckerTests {

    @Test("Installed when ocak key present in plugins")
    func installedWhenOcakKeyPresent() throws {
        let path = try writeTempInstalledPlugins("""
        {
          "version": 2,
          "plugins": {
            "ocak@local": [{"scope": "user", "installPath": "/Users/test/.ocak/plugin", "version": "1.0.0"}]
          }
        }
        """)
        defer { try? FileManager.default.removeItem(atPath: path) }
        #expect(PluginStatusChecker.isInstalled(installedPluginsPath: path) == true)
    }

    @Test("Installed when ocak key without marketplace suffix")
    func installedWhenOcakKeyNoSuffix() throws {
        let path = try writeTempInstalledPlugins("""
        {
          "version": 2,
          "plugins": {
            "ocak": [{"scope": "user", "installPath": "/Users/test/.ocak/plugin", "version": "1.0.0"}]
          }
        }
        """)
        defer { try? FileManager.default.removeItem(atPath: path) }
        #expect(PluginStatusChecker.isInstalled(installedPluginsPath: path) == true)
    }

    @Test("Not installed when only other plugins present")
    func notInstalledWhenOtherPluginsOnly() throws {
        let path = try writeTempInstalledPlugins("""
        {
          "version": 2,
          "plugins": {
            "frontend-design@claude-plugins-official": [{"scope": "user", "installPath": "/some/path", "version": "1.0.0"}]
          }
        }
        """)
        defer { try? FileManager.default.removeItem(atPath: path) }
        #expect(PluginStatusChecker.isInstalled(installedPluginsPath: path) == false)
    }

    @Test("Not installed when plugins object is empty")
    func notInstalledWhenPluginsEmpty() throws {
        let path = try writeTempInstalledPlugins("""
        { "version": 2, "plugins": {} }
        """)
        defer { try? FileManager.default.removeItem(atPath: path) }
        #expect(PluginStatusChecker.isInstalled(installedPluginsPath: path) == false)
    }

    @Test("Not installed when file is missing")
    func notInstalledWhenFileMissing() {
        let path = "/tmp/nonexistent-ocak-\(UUID().uuidString)/installed_plugins.json"
        #expect(PluginStatusChecker.isInstalled(installedPluginsPath: path) == false)
    }

    @Test("Not installed when JSON is invalid")
    func notInstalledWhenInvalidJSON() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("installed_plugins.json").path
        defer { try? FileManager.default.removeItem(at: dir) }
        try "not json{{".write(toFile: path, atomically: true, encoding: .utf8)
        #expect(PluginStatusChecker.isInstalled(installedPluginsPath: path) == false)
    }

    // MARK: - Helpers

    private func writeTempInstalledPlugins(_ json: String) throws -> String {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("installed_plugins.json").path
        try json.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }
}
