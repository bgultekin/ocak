import Foundation
import Combine
import SwiftUI

private let descriptors = [
    "Smoldering", "Sizzling", "Charred", "Molten", "Overcooked",
    "Raw", "Lukewarm", "Blazing", "Flambéed", "Toasty",
    "Nuclear", "Volcanic", "Crispy", "Singed", "Carbonized",
    "Spicy", "Smokey", "Fermented", "Glazed", "Aggressive"
]

private let nouns = [
    "Anvil", "Spatula", "Briquette", "Ember", "Skillet",
    "Piston", "Goulash", "Dumpling", "Chimney", "Bellows",
    "Ladle", "Furnace", "Cinder", "Apron", "Cauldron",
    "Spark", "Meatball", "Soufflé", "Log", "Griddle"
]

private func randomName() -> String {
    let descriptor = descriptors.randomElement()!
    let noun = nouns.randomElement()!
    return "\(descriptor) \(noun)"
}

@Observable
final class SessionStore {
    var sessions: [ThreadSession] = []
    var groups: [SessionGroup] = []
    var activeSessionID: UUID?
    var isSidebarVisible: Bool = true
    var isPanelVisible: Bool = false
    var hasAttention: Bool { sessions.contains { $0.status == .needs_input } }
    var allSessionIDs: Set<UUID> { Set(sessions.map(\.id)) }
    var hasWorking: Bool { sessions.contains { $0.status == .working } }
    var hasDone: Bool { sessions.contains { $0.status == .done } }
    var lastCompletionTime: Date?
    var showSuccessFlash: Bool = false

    /// IDs of sessions whose prompts are currently being summarized for auto-rename.
    /// Used to deduplicate rapid `UserPromptSubmit` events while a summary is in flight.
    private var summariesInFlight: Set<UUID> = []

    var activeSession: ThreadSession? {
        get { sessions.first { $0.id == activeSessionID } }
        set {
            if let newValue, let idx = sessions.firstIndex(where: { $0.id == newValue.id }) {
                sessions[idx] = newValue
            }
        }
    }

    /// Sessions grouped by explicit SessionGroup, sorted by order.
    var groupedSessions: [(group: SessionGroup, sessions: [ThreadSession])] {
        groups
            .sorted { $0.order < $1.order }
            .map { group in
                let groupSessions = sessions
                    .filter { $0.groupID == group.id }
                    .sorted { $0.order < $1.order }
                return (group: group, sessions: groupSessions)
            }
    }

    // MARK: - Group Operations

    @discardableResult
    func addGroup() -> SessionGroup {
        let maxOrder = groups.map { $0.order }.max() ?? -1
        let group = SessionGroup(name: randomName(), order: maxOrder + 1)
        groups.append(group)
        save()
        return group
    }

    func renameGroup(_ id: UUID, name: String) {
        if let idx = groups.firstIndex(where: { $0.id == id }) {
            groups[idx].name = name
            save()
        }
    }

    func updateGroupDirectory(_ id: UUID, directory: String?) {
        if let idx = groups.firstIndex(where: { $0.id == id }) {
            groups[idx].directory = directory
            save()
        }
    }

    func updateGroupInitialCommand(_ id: UUID, command: String?) {
        if let idx = groups.firstIndex(where: { $0.id == id }) {
            groups[idx].initialCommand = command
            save()
        }
    }

    func setGroupCollapsed(_ id: UUID, collapsed: Bool) {
        if let idx = groups.firstIndex(where: { $0.id == id }) {
            guard groups[idx].isCollapsed != collapsed else { return }
            groups[idx].isCollapsed = collapsed
            save()
        }
    }

    func removeGroup(_ id: UUID) {
        sessions.filter { $0.groupID == id }.map(\.id).forEach { removeSession($0) }
        groups.removeAll { $0.id == id }
        save()
    }

    func moveGroup(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex else { return }
        let sortedGroups = groups.sorted { $0.order < $1.order }
        var reordered = sortedGroups
        let moved = reordered.remove(at: sourceIndex)
        reordered.insert(moved, at: destinationIndex)
        for (index, group) in reordered.enumerated() {
            if let idx = groups.firstIndex(where: { $0.id == group.id }) {
                groups[idx].order = index
            }
        }
        save()
    }

    func moveSession(_ sessionID: UUID, toGroup groupID: UUID, at destinationIndex: Int) {
        guard let sessionIdx = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        let sourceGroupID = sessions[sessionIdx].groupID
        sessions[sessionIdx].groupID = groupID

        let sourceSessions = sessions
            .filter { $0.groupID == sourceGroupID && $0.id != sessionID }
            .sorted { $0.order < $1.order }
        for (i, session) in sourceSessions.enumerated() {
            if let sIdx = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[sIdx].order = i
            }
        }

        var targetSessions = sessions
            .filter { $0.groupID == groupID && $0.id != sessionID }
            .sorted { $0.order < $1.order }
        let insertAt = min(destinationIndex, targetSessions.count)
        if let sIdx = sessions.firstIndex(where: { $0.id == sessionID }) {
            targetSessions.insert(sessions[sIdx], at: insertAt)
        }
        for (i, session) in targetSessions.enumerated() {
            if let sIdx = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[sIdx].order = i
            }
        }

        save()
    }

    func reorderSessionInGroup(_ groupID: UUID, sessionID: UUID, to destinationIndex: Int) {
        var groupSessions = sessions
            .filter { $0.groupID == groupID }
            .sorted { $0.order < $1.order }
        guard let sourceIndex = groupSessions.firstIndex(where: { $0.id == sessionID }) else { return }
        let moved = groupSessions.remove(at: sourceIndex)
        let adjustedDest = min(destinationIndex, groupSessions.count)
        groupSessions.insert(moved, at: adjustedDest)
        for (i, session) in groupSessions.enumerated() {
            if let sIdx = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[sIdx].order = i
            }
        }
        save()
    }

    // MARK: - Session Operations

    func addSession(name: String, directory: String, groupID: UUID, tool: AITool, command: String) {
        let session = ThreadSession(
            name: name,
            workingDirectory: directory,
            groupID: groupID,
            aiTool: tool,
            command: command
        )
        sessions.append(session)
        if activeSessionID == nil {
            activeSessionID = session.id
        }
    }

    @discardableResult
    func addQuickSession(in groupID: UUID) -> ThreadSession {
        let directory = groups.first(where: { $0.id == groupID })?.directory
            ?? FileManager.default.homeDirectoryForCurrentUser.path
        let session = ThreadSession(
            name: randomName(),
            workingDirectory: directory,
            groupID: groupID,
            aiTool: .claudeCode
        )
        sessions.append(session)
        activeSessionID = session.id
        return session
    }

    func updateDirectory(_ id: UUID, directory: String) {
        if let idx = sessions.firstIndex(where: { $0.id == id }) {
            sessions[idx].workingDirectory = directory
            save()
        }
    }

    func removeSession(_ id: UUID) {
        TerminalManager.shared.removeTerminal(for: id)
        let idx = sessions.firstIndex(where: { $0.id == id })
        sessions.removeAll { $0.id == id }
        summariesInFlight.remove(id)
        if activeSessionID == id {
            if let idx {
                if idx > 0, idx - 1 < sessions.count {
                    activeSessionID = sessions[idx - 1].id
                } else if idx < sessions.count {
                    activeSessionID = sessions[idx].id
                } else {
                    activeSessionID = sessions.first?.id
                }
            } else {
                activeSessionID = sessions.first?.id
            }
        }
    }

    func selectSession(_ id: UUID) {
        activeSessionID = id
    }

    func renameSession(_ id: UUID, name: String) {
        if let idx = sessions.firstIndex(where: { $0.id == id }) {
            sessions[idx].name = name
            sessions[idx].hasManualName = true
            save()
        }
    }

    /// Summarizer-driven rename. Only applies if `expectedCurrentName` still matches (so a
    /// manual rename during an in-flight summary wins) and the user hasn't since renamed
    /// manually. Records `agentSessionId` so repeated prompts in the same agent session
    /// don't trigger additional renames.
    private func applyAutoGeneratedName(
        _ id: UUID, name: String, expectedCurrentName: String, agentSessionId: String
    ) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        guard !sessions[idx].hasManualName else { return }
        guard sessions[idx].name == expectedCurrentName else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        sessions[idx].name = trimmed
        sessions[idx].lastAutoNamedAgentSessionId = agentSessionId
        save()
    }

    private func triggerSuccessFlash() {
        showSuccessFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.showSuccessFlash = false
        }
    }

    func clearSessionStatuses() {
        for idx in sessions.indices {
            let s = sessions[idx].status
            if s == .done || s == .needs_input {
                sessions[idx].status = .new
            }
        }
    }

    func updateStatus(_ id: UUID, status: SessionStatus) {
        if let idx = sessions.firstIndex(where: { $0.id == id }) {
            let previous = sessions[idx].status
            sessions[idx].status = status
            if previous == .working && status == .done {
                lastCompletionTime = Date()
                triggerSuccessFlash()
            }
        }
    }

    func updateAgentRunning(_ id: UUID, isRunning: Bool) {
        if let idx = sessions.firstIndex(where: { $0.id == id }) {
            sessions[idx].isAgentRunning = isRunning
        }
    }

    func updateDetectedAgent(_ id: UUID, detectedAgent: AITool?) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        let wasRunning = sessions[idx].isAgentRunning
        let nowRunning = detectedAgent != nil
        guard wasRunning != nowRunning || sessions[idx].detectedAgent != detectedAgent else { return }

        sessions[idx].isAgentRunning = nowRunning
        sessions[idx].detectedAgent = detectedAgent

        // Agent disappeared while session was active → auto-complete (covers crashes/kills with no Stop hook)
        if wasRunning && !nowRunning {
            let current = sessions[idx].status
            if current == .working || current == .needs_input {
                sessions[idx].status = .done
                if current == .working {
                    lastCompletionTime = Date()
                    triggerSuccessFlash()
                }
            }
        }
    }

    /// Process an incoming AI agent hook event and update the corresponding session's status.
    func processHookEvent(_ event: HookEvent) {

        guard let idx = findSessionIndex(for: event) else { return }

        // Kick off prompt-based auto-rename before status handling. Runs at most once per
        // distinct agent session id — so `/clear`, `/new`, or a fresh `claude` invocation
        // (all of which mint a new `session_id`) will retitle the terminal, but repeated
        // prompts within the same conversation won't. Manual renames are sticky.
        if event.hookEventName == "UserPromptSubmit",
           !sessions[idx].hasManualName,
           !event.sessionId.isEmpty,
           sessions[idx].lastAutoNamedAgentSessionId != event.sessionId,
           !summariesInFlight.contains(sessions[idx].id),
           let prompt = event.prompt?.trimmingCharacters(in: .whitespacesAndNewlines),
           !prompt.isEmpty {
            let sessionID = sessions[idx].id
            let currentName = sessions[idx].name
            let agentSessionId = event.sessionId
            summariesInFlight.insert(sessionID)
            TerminalNameSummarizer.summarize(prompt: prompt) { [weak self] name in
                guard let self else { return }
                self.summariesInFlight.remove(sessionID)
                guard let name else { return }
                self.applyAutoGeneratedName(
                    sessionID,
                    name: name,
                    expectedCurrentName: currentName,
                    agentSessionId: agentSessionId
                )
            }
        }

        // Shell-level events are dropped while an agent is running (agent events take precedence)
        if sessions[idx].isAgentRunning &&
            (event.hookEventName == "ShellCommandStart" || event.hookEventName == "ShellCommandEnd") {
            return
        }

        // Don't overwrite .done with working events (late tool events after session ended).
        // SessionStart and UserPromptSubmit are intentionally excluded — they represent a new
        // Claude invocation in the same terminal and should re-activate the session.
        if sessions[idx].status == .done {
            switch event.hookEventName {
            case "PostToolUse", "PreToolUse",
                 "PostToolUseFailure", "SubagentStart", "SubagentStop", "TeammateIdle",
                 "InstructionsLoaded", "ConfigChange", "WorktreeCreate", "WorktreeRemove",
                 "PreCompact", "PostCompact", "ShellCommandStart":
                return
            default:
                break
            }
        }

        let newStatus: SessionStatus
        switch event.hookEventName {
        case "PostToolUse":
            if sessions[idx].status == .needs_input { return }
            newStatus = .working
        case "SessionStart", "UserPromptSubmit", "PreToolUse",
             "PostToolUseFailure", "SubagentStart", "SubagentStop", "TeammateIdle",
             "InstructionsLoaded", "ConfigChange", "WorktreeCreate", "WorktreeRemove",
             "PreCompact", "PostCompact":
            newStatus = .working
        case "PermissionRequest", "Notification", "TaskCompleted",
             "Elicitation", "ElicitationResult":
            newStatus = .needs_input
        case "Stop", "StopFailure", "SessionEnd":
            newStatus = .done
        case "ShellCommandStart":
            newStatus = .working
        case "ShellCommandEnd":
            newStatus = .done
        default:
            return
        }

        let previous = sessions[idx].status
        sessions[idx].status = newStatus
        if previous == .working && newStatus == .done {
            lastCompletionTime = Date()
            triggerSuccessFlash()
        }
    }

    /// Find the session index for a hook event, trying direct UUID match first, then cwd fallback.
    private func findSessionIndex(for event: HookEvent) -> Int? {
        // 1. Direct UUID match (Claude Code path)
        if let uuidString = event.ocakSessionId,
           let id = UUID(uuidString: uuidString),
           let idx = sessions.firstIndex(where: { $0.id == id }) {
            return idx
        }

        // 2. Match by working directory (OpenCode path)
        // Only match sessions that are .new or .working (not .done) to avoid stale matches
        let cwd = event.cwd
        if !cwd.isEmpty {
            let normalizedCwd = (cwd as NSString).resolvingSymlinksInPath
            let candidates = sessions.enumerated().filter { _, s in
                (s.status == .new || s.status == .working) &&
                (s.workingDirectory == cwd || (s.workingDirectory as NSString).resolvingSymlinksInPath == normalizedCwd)
            }

            // If only one candidate, use it
            if candidates.count == 1 {
                return candidates[0].offset
            }

            // If multiple candidates, prefer the one with the most recent createdAt
            if let best = candidates.max(by: { $0.element.createdAt < $1.element.createdAt }) {
                return best.offset
            }
        }

        return nil
    }

    // MARK: - Persistence

    private static let storageKey = "ocak.sessions"
    private static let groupsStorageKey = "ocak.groups"

    func save() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
        if let data = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(data, forKey: Self.groupsStorageKey)
        }
    }

    func restore() {
        // Restore groups
        if let data = UserDefaults.standard.data(forKey: Self.groupsStorageKey),
           let savedGroups = try? JSONDecoder().decode([SessionGroup].self, from: data) {
            groups = savedGroups
        }

        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else {
        if groups.isEmpty {
            createDefaultFirstRunData()
        }
        return
    }

        // Try new format (sessions with groupID)
        if let saved = try? JSONDecoder().decode([ThreadSession].self, from: data) {
            if groups.isEmpty && !saved.isEmpty {
                // Groups key was lost — recover by creating stub groups per unique groupID
                migrateOrphanedSessions(saved)
            } else {
                sessions = saved
                resetRuntimeSessionState()
            }
        } else if let legacy = try? JSONDecoder().decode([LegacyThreadSession].self, from: data) {
            // Old format — no groupID field; create groups from unique workingDirectories
            migrateFromLegacy(legacy)
        }

        activeSessionID = sessions.first?.id

        if groups.isEmpty && sessions.isEmpty {
            createDefaultFirstRunData()
        }
    }

    private func createDefaultFirstRunData() {
        let group = SessionGroup(name: randomName(), order: 0)
        groups.append(group)
        let session = ThreadSession(
            name: randomName(),
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            groupID: group.id,
            aiTool: .claudeCode
        )
        sessions.append(session)
        activeSessionID = session.id
        save()
    }

    private func resetRuntimeSessionState() {
        for i in sessions.indices {
            sessions[i].status = .new
            sessions[i].isAgentRunning = false
            sessions[i].detectedAgent = nil
        }
    }

    private func migrateFromLegacy(_ legacy: [LegacyThreadSession]) {
        let byDir = Dictionary(grouping: legacy) { $0.workingDirectory }
        var dirToGroupID: [String: UUID] = [:]
        for dir in byDir.keys.sorted() {
            let name = URL(fileURLWithPath: dir).lastPathComponent
            let group = SessionGroup(name: name, directory: dir)
            groups.append(group)
            dirToGroupID[dir] = group.id
        }
        sessions = legacy.map { leg in
            ThreadSession(
                id: leg.id,
                name: leg.name,
                workingDirectory: leg.workingDirectory,
                groupID: dirToGroupID[leg.workingDirectory]!,
                aiTool: leg.aiTool,
                command: leg.command,
                status: .new
            )
        }
        save()
    }

    private func migrateOrphanedSessions(_ orphaned: [ThreadSession]) {
        let missingIDs = Set(orphaned.map { $0.groupID }).subtracting(Set(groups.map { $0.id }))
        for id in missingIDs {
            groups.append(SessionGroup(id: id, name: "Recovered Group"))
        }
        sessions = orphaned
        resetRuntimeSessionState()
        save()
    }
}

// MARK: - Legacy migration helper (old JSON format — no groupID field)

private struct LegacyThreadSession: Codable {
    let id: UUID
    var name: String
    var workingDirectory: String
    var aiTool: AITool
    var status: SessionStatus
    var command: String
    var lastOutput: String
    var createdAt: Date
}
