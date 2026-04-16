import Foundation

/// Represents a decoded AI coding agent hook event POST body.
/// The `ocakSessionId` is read from the `X-Ocak-Session` HTTP header by HookServer.
struct HookEvent: Decodable {
    let hookEventName: String
    let sessionId: String
    let cwd: String
    let notificationType: String?
    let toolName: String?
    /// Set by HookServer from the X-Ocak-Session HTTP header, not from the JSON body.
    var ocakSessionId: String?

    enum CodingKeys: String, CodingKey {
        case hookEventName = "hook_event_name"
        case sessionId = "session_id"
        case cwd
        case notificationType = "notification_type"
        case toolName = "tool_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hookEventName = try c.decode(String.self, forKey: .hookEventName)
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId) ?? ""
        cwd = try c.decodeIfPresent(String.self, forKey: .cwd) ?? ""
        notificationType = try c.decodeIfPresent(String.self, forKey: .notificationType)
        toolName = try c.decodeIfPresent(String.self, forKey: .toolName)
    }
}
