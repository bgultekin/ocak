import Testing
import Foundation

// Local copies for testing (cannot import executable target)
private enum SessionStatus: String, Codable, Equatable {
    case new
    case working
    case needs_input
    case done
}

/// Minimal session state used to test processHookEvent logic.
private struct SessionState {
    var status: SessionStatus = .new
    var isAgentRunning: Bool = false
    var lastCompletionTime: Date?
}

/// Mirror of SessionStore.processHookEvent dispatch logic, extracted for unit testing.
private func processEvent(eventName: String, session: inout SessionState) {
    // Drop shell-level events while an agent is running
    if session.isAgentRunning &&
        (eventName == "ShellCommandStart" || eventName == "ShellCommandEnd") {
        return
    }

    // Don't overwrite .done with stale working events
    if session.status == .done {
        switch eventName {
        case "PostToolUse", "SessionStart", "UserPromptSubmit", "PreToolUse",
             "PostToolUseFailure", "SubagentStart", "SubagentStop", "TeammateIdle",
             "InstructionsLoaded", "ConfigChange", "WorktreeCreate", "WorktreeRemove",
             "PreCompact", "PostCompact", "ShellCommandStart":
            return
        default:
            break
        }
    }

    let newStatus: SessionStatus
    switch eventName {
    case "PostToolUse":
        if session.status == .needs_input { return }
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

    let previous = session.status
    session.status = newStatus
    if previous == .working && newStatus == .done {
        session.lastCompletionTime = Date()
    }
}

@Suite("SessionStore — shell command status events")
struct SessionStoreTests {

    // MARK: - ShellCommandStart

    @Test("ShellCommandStart with isAgentRunning=false -> .working")
    func shellCommandStart_noAgent_setsWorking() {
        var session = SessionState(status: .new, isAgentRunning: false)
        processEvent(eventName: "ShellCommandStart", session: &session)
        #expect(session.status == .working)
    }

    @Test("ShellCommandStart with isAgentRunning=true -> status unchanged")
    func shellCommandStart_agentRunning_dropped() {
        var session = SessionState(status: .new, isAgentRunning: true)
        processEvent(eventName: "ShellCommandStart", session: &session)
        #expect(session.status == .new)
    }

    // MARK: - ShellCommandEnd

    @Test("ShellCommandEnd with isAgentRunning=false -> .done")
    func shellCommandEnd_noAgent_setsDone() {
        var session = SessionState(status: .working, isAgentRunning: false)
        processEvent(eventName: "ShellCommandEnd", session: &session)
        #expect(session.status == .done)
    }

    @Test("ShellCommandEnd with isAgentRunning=false sets lastCompletionTime when transitioning from .working")
    func shellCommandEnd_noAgent_setsLastCompletionTime() {
        var session = SessionState(status: .working, isAgentRunning: false)
        #expect(session.lastCompletionTime == nil)
        processEvent(eventName: "ShellCommandEnd", session: &session)
        #expect(session.lastCompletionTime != nil)
    }

    @Test("ShellCommandEnd with isAgentRunning=true -> status unchanged")
    func shellCommandEnd_agentRunning_dropped() {
        var session = SessionState(status: .working, isAgentRunning: true)
        processEvent(eventName: "ShellCommandEnd", session: &session)
        #expect(session.status == .working)
    }

    // MARK: - Late event suppression

    @Test("Late ShellCommandStart after .done -> stays .done")
    func shellCommandStart_afterDone_suppressed() {
        var session = SessionState(status: .done, isAgentRunning: false)
        processEvent(eventName: "ShellCommandStart", session: &session)
        #expect(session.status == .done)
    }

    @Test("ShellCommandEnd after .done -> stays .done (no regression)")
    func shellCommandEnd_afterDone_setsDoneAgain() {
        // ShellCommandEnd is not in the suppression list — it transitions to .done regardless,
        // which is a no-op since status is already .done.
        var session = SessionState(status: .done, isAgentRunning: false)
        processEvent(eventName: "ShellCommandEnd", session: &session)
        #expect(session.status == .done)
    }
}
