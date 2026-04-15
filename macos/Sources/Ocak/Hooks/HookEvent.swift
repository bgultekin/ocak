import Foundation

/// Represents a decoded AI coding agent hook event POST body.
/// The `ocakSessionId` field is injected by the hook command from the $OCAK_SESSION_ID env var.
struct HookEvent: Decodable {
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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hookEventName = try c.decode(String.self, forKey: .hookEventName)
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId) ?? ""
        cwd = try c.decodeIfPresent(String.self, forKey: .cwd) ?? ""
        notificationType = try c.decodeIfPresent(String.self, forKey: .notificationType)
        toolName = try c.decodeIfPresent(String.self, forKey: .toolName)
        ocakSessionId = try c.decodeIfPresent(String.self, forKey: .ocakSessionId)
    }
}
