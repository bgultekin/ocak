import Testing
import Foundation

// Local copy for testing
private struct HookEvent: Decodable {
    let hookEventName: String
    let sessionId: String
    let cwd: String
    let notificationType: String?
    let toolName: String?
    let ocakSessionId: String?

    enum CodingKeys: String, CodingKey {
        case hookEventName = "hook_event_name"
        case sessionId = "session_id"
        case cwd
        case notificationType = "notification_type"
        case toolName = "tool_name"
        case ocakSessionId = "ocak_session_id"
    }
}

@Suite("Hook Event Decoding")
struct HookEventTests {
    @Test("Decode UserPromptSubmit event")
    func decode_userPromptSubmit() throws {
        let jsonString = """
        {
            "hook_event_name": "UserPromptSubmit",
            "session_id": "abc-123",
            "cwd": "/Users/test/project",
            "ocak_session_id": "550e8400-e29b-41d4-a716-446655440000"
        }
        """
        let event = try JSONDecoder().decode(HookEvent.self, from: Data(jsonString.utf8))
        #expect(event.hookEventName == "UserPromptSubmit")
        #expect(event.ocakSessionId == "550e8400-e29b-41d4-a716-446655440000")
        #expect(event.toolName == nil)
    }

    @Test("Decode PermissionRequest event with toolName")
    func decode_permissionRequest() throws {
        let jsonString = """
        {
            "hook_event_name": "PermissionRequest",
            "session_id": "abc-123",
            "cwd": "/Users/test",
            "tool_name": "Bash",
            "ocak_session_id": "550e8400-e29b-41d4-a716-446655440000"
        }
        """
        let event = try JSONDecoder().decode(HookEvent.self, from: Data(jsonString.utf8))
        #expect(event.hookEventName == "PermissionRequest")
        #expect(event.toolName == "Bash")
    }

    @Test("Decode event without ocak_session_id (non-Ocak session)")
    func decode_noOcakSessionId() throws {
        let jsonString = """
        {
            "hook_event_name": "Stop",
            "session_id": "abc-123",
            "cwd": "/Users/test"
        }
        """
        let event = try JSONDecoder().decode(HookEvent.self, from: Data(jsonString.utf8))
        #expect(event.ocakSessionId == nil)
    }

    @Test("Decode Stop event")
    func decode_stop() throws {
        let jsonString = """
        {
            "hook_event_name": "Stop",
            "session_id": "abc-123",
            "cwd": "/tmp",
            "ocak_session_id": "550e8400-e29b-41d4-a716-446655440000"
        }
        """
        let event = try JSONDecoder().decode(HookEvent.self, from: Data(jsonString.utf8))
        #expect(event.hookEventName == "Stop")
    }

    @Test("Decode SessionEnd event")
    func decode_sessionEnd() throws {
        let jsonString = """
        {
            "hook_event_name": "SessionEnd",
            "session_id": "abc-123",
            "cwd": "/tmp",
            "ocak_session_id": "550e8400-e29b-41d4-a716-446655440000"
        }
        """
        let event = try JSONDecoder().decode(HookEvent.self, from: Data(jsonString.utf8))
        #expect(event.hookEventName == "SessionEnd")
    }
}
