import Testing
import Foundation

@Suite("Hook Installer — STAT-05")
struct HookInstallerTests {

    // MARK: - plugin.json static file tests

    @Test("plugin.json is valid JSON")
    func pluginJson_isValidJSON() throws {
        let data = try loadPluginJson()
        #expect(throws: Never.self) { try JSONSerialization.jsonObject(with: data) }
    }

    @Test("plugin.json has name ocak")
    func pluginJson_hasCorrectName() throws {
        let json = try parsePluginJson()
        #expect((json["name"] as? String) == "ocak")
    }

    @Test("plugin.json contains all six event types")
    func pluginJson_containsAllSixEvents() throws {
        let json = try parsePluginJson()
        let hooks = try #require(json["hooks"] as? [String: Any])
        for event in ["UserPromptSubmit", "PreToolUse", "PostToolUse", "PermissionRequest", "Stop", "SessionEnd"] {
            #expect(hooks[event] != nil, "Missing event: \(event)")
        }
    }

    @Test("plugin.json command contains OCAK_SESSION_ID guard")
    func pluginJson_commandContainsGuard() throws {
        #expect(try firstCommand().contains("[ -z \"$OCAK_SESSION_ID\" ] && exit 0"))
    }

    @Test("plugin.json command is non-blocking")
    func pluginJson_commandIsNonBlocking() throws {
        #expect(try firstCommand().contains("|| true"))
    }

    @Test("plugin.json command posts to port 27832")
    func pluginJson_commandCorrectPort() throws {
        #expect(try firstCommand().contains("http://localhost:27832/hook"))
    }

    @Test("plugin.json command injects ocak_session_id")
    func pluginJson_commandInjectsSessionId() throws {
        #expect(try firstCommand().contains("ocak_session_id"))
    }

    // MARK: - Helpers

    private func pluginResourceURL() throws -> URL {
        let thisFile = URL(fileURLWithPath: #filePath)
        let packageRoot = thisFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return packageRoot.appendingPathComponent("Sources/Ocak/Resources/claude-ocak-marketplace/plugins/ocak")
    }

    private func loadPluginJson() throws -> Data {
        let url = try pluginResourceURL().appendingPathComponent(".claude-plugin/plugin.json")
        return try Data(contentsOf: url)
    }

    private func parsePluginJson() throws -> [String: Any] {
        let data = try loadPluginJson()
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func firstCommand() throws -> String {
        let json = try parsePluginJson()
        let hooks = try #require(json["hooks"] as? [String: Any])
        let firstEvent = try #require(hooks.values.first as? [[String: Any]])
        let hookArray = try #require(firstEvent.first?["hooks"] as? [[String: Any]])
        return try #require(hookArray.first?["command"] as? String)
    }
}
