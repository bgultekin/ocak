import Testing
import Foundation

// Local copy for testing (cannot import executable target) — mirrors PluginVersionManager
private enum PVM {
    static func extractVersion(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = json["version"] as? String else { return nil }
        return version
    }

    static func isVersionGreater(_ v1: String, than v2: String) -> Bool {
        let p1 = v1.split(separator: ".").compactMap { Int($0) }
        let p2 = v2.split(separator: ".").compactMap { Int($0) }
        guard p1.count >= 3 && p2.count >= 3 else { return false }
        if p1[0] != p2[0] { return p1[0] > p2[0] }
        if p1[1] != p2[1] { return p1[1] > p2[1] }
        return p1[2] > p2[2]
    }

    static func readBundledPluginVersion() throws -> String? {
        let thisFile = URL(fileURLWithPath: #filePath)
        let root = thisFile.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent(
            "Sources/Ocak/Resources/claude-ocak-marketplace/plugins/ocak/.claude-plugin/plugin.json"
        )
        let data = try Data(contentsOf: url)
        return extractVersion(from: data)
    }

    static func readInstalledPluginVersion(installedPluginsPath: String) throws -> String? {
        guard FileManager.default.fileExists(atPath: installedPluginsPath),
              let data = FileManager.default.contents(atPath: installedPluginsPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let plugins = json["plugins"] as? [String: Any] else { return nil }
        let key = plugins.keys.first { $0 == "ocak" || $0 == "ocak@ocak-plugins" || $0.hasPrefix("ocak@") }
        guard let key,
              let arr = plugins[key] as? [[String: Any]],
              let first = arr.first,
              let version = first["version"] as? String else { return nil }
        return version
    }
}

@Suite("Plugin Version Management — Integration")
struct PluginUpdateIntegrationTests {

    @Test("Detects when bundled version is newer than installed")
    func detectsNewerBundledVersion() throws {
        let installedJSON = """
        {
          "version": 2,
          "plugins": {
            "ocak@ocak-plugins": [
              {"scope": "user", "installPath": "/test/path", "version": "1.0.0"}
            ]
          }
        }
        """
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let installedPath = dir.appendingPathComponent("installed_plugins.json").path
        try installedJSON.write(toFile: installedPath, atomically: true, encoding: .utf8)

        let installed = try PVM.readInstalledPluginVersion(installedPluginsPath: installedPath)
        let bundled = try PVM.readBundledPluginVersion()

        guard let installed, let bundled else {
            Issue.record("Could not read versions")
            return
        }

        let needsUpdate = PVM.isVersionGreater(bundled, than: installed)
        #expect(needsUpdate == true, "Bundled version should be newer than 1.0.0")
    }

    @Test("Handles missing installed plugin gracefully")
    func handlesMissingInstalledPlugin() throws {
        let nonexistentPath = "/tmp/nonexistent-\(UUID().uuidString)/installed_plugins.json"
        let installed = try PVM.readInstalledPluginVersion(installedPluginsPath: nonexistentPath)
        #expect(installed == nil)
    }

    @Test("Reads actual bundled plugin version successfully")
    func readsActualBundledVersion() throws {
        let version = try PVM.readBundledPluginVersion()
        #expect(version != nil, "Should read bundled plugin version")
        #expect((version ?? "").count > 0, "Version should not be empty")
    }
}
