import Foundation

enum SessionStatus: String, Codable {
    case new
    case working
    case needs_input
    case done
}

enum AITool: String, Codable, CaseIterable {
    case claudeCode = "claude-code"
    case opencode = "opencode"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .opencode: return "OpenCode"
        case .custom: return "custom"
        }
    }

    var statusIcon: String {
        switch self {
        case .claudeCode: return "asterisk.circle.fill"
        case .opencode: return "slash.circle"
        case .custom: return "terminal"
        }
    }
}

struct ThreadSession: Identifiable, Codable {
    let id: UUID
    var name: String
    var workingDirectory: String
    var groupID: UUID
    var aiTool: AITool
    var status: SessionStatus
    var command: String
    var order: Int
    var createdAt: Date
    /// Runtime-only: true when the AI agent process is detected as a descendant of this session's shell.
    /// Not persisted — resets to false on restore. Excluded from CodingKeys intentionally.
    var isAgentRunning: Bool = false
    /// Runtime-only: which agent binary is actually running (detected via process scan).
    /// Falls back to `aiTool` for icon display. Excluded from CodingKeys intentionally.
    var detectedAgent: AITool? = nil
    enum CodingKeys: String, CodingKey {
        case id, name, workingDirectory, groupID, aiTool, status, command, order, createdAt
    }

    init(
        id: UUID = UUID(),
        name: String,
        workingDirectory: String,
        groupID: UUID,
        aiTool: AITool = .claudeCode,
        command: String = "",
        status: SessionStatus = .new,
        order: Int = 0
    ) {
        self.id = id
        self.name = name
        self.workingDirectory = workingDirectory
        self.groupID = groupID
        self.aiTool = aiTool
        self.command = command
        self.status = status
        self.order = order
        self.createdAt = Date()
    }

    var shortPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if workingDirectory.hasPrefix(home) {
            return "~" + workingDirectory.dropFirst(home.count)
        }
        return workingDirectory
    }

    var projectName: String {
        URL(fileURLWithPath: workingDirectory).lastPathComponent
    }

    /// Returns the SF Symbol name for the session's status icon.
    /// Uses the detected agent if running, otherwise falls back to terminal.
    var statusIcon: String {
        if let detected = detectedAgent {
            return detected.statusIcon
        }
        return "terminal"
    }
}
