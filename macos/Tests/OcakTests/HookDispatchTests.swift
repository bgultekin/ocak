import Testing
import Foundation

// Local copies for testing (cannot import executable target)
private enum SessionStatus: String, Codable {
    case new
    case working
    case needs_input
    case done
}

/// Minimal state machine that mirrors SessionStore.processHookEvent logic.
/// Extracted here so we can unit test the dispatch without needing SessionStore.
private func dispatch(eventName: String, currentStatus: SessionStatus) -> SessionStatus? {
    switch eventName {
    case "PostToolUse":
        if currentStatus == .needs_input { return nil }
        return .working
    case "SessionStart":
        return .new
    case "UserPromptSubmit", "PreToolUse",
         "PostToolUseFailure", "SubagentStart", "SubagentStop", "TeammateIdle",
         "InstructionsLoaded", "ConfigChange", "WorktreeCreate", "WorktreeRemove",
         "PreCompact", "PostCompact":
        return .working
    case "PermissionRequest", "Notification", "TaskCompleted",
         "Elicitation", "ElicitationResult":
        return .needs_input
    case "Stop", "StopFailure", "SessionEnd":
        return .done
    default:
        return nil
    }
}

@Suite("Hook Event Dispatch — STAT-02, STAT-03, STAT-04")
struct HookDispatchTests {
    @Test("UserPromptSubmit -> working")
    func userPromptSubmit_setsWorking() {
        #expect(dispatch(eventName: "UserPromptSubmit", currentStatus: .new) == .working)
    }

    @Test("PreToolUse -> working")
    func preToolUse_setsWorking() {
        #expect(dispatch(eventName: "PreToolUse", currentStatus: .working) == .working)
    }

    @Test("PostToolUse -> working")
    func postToolUse_setsWorking() {
        #expect(dispatch(eventName: "PostToolUse", currentStatus: .working) == .working)
    }

    @Test("PostToolUse does NOT overwrite needs_input")
    func postToolUse_doesNotOverwrite_needsInput() {
        #expect(dispatch(eventName: "PostToolUse", currentStatus: .needs_input) == nil)
    }

    @Test("PostToolUseFailure -> working")
    func postToolUseFailure_setsWorking() {
        #expect(dispatch(eventName: "PostToolUseFailure", currentStatus: .working) == .working)
    }

    @Test("SessionStart -> new (Claude just launched, not working yet)")
    func sessionStart_setsNew() {
        #expect(dispatch(eventName: "SessionStart", currentStatus: .new) == .new)
    }

    @Test("SessionStart after .done resets to .new (re-activated as idle)")
    func sessionStart_fromDone_resetsToNew() {
        #expect(dispatch(eventName: "SessionStart", currentStatus: .done) == .new)
    }

    @Test("PermissionRequest -> needs_input")
    func permissionRequest_setsNeedsInput() {
        #expect(dispatch(eventName: "PermissionRequest", currentStatus: .working) == .needs_input)
    }

    @Test("Notification -> needs_input")
    func notification_setsNeedsInput() {
        #expect(dispatch(eventName: "Notification", currentStatus: .working) == .needs_input)
    }

    @Test("TaskCompleted -> needs_input")
    func taskCompleted_setsNeedsInput() {
        #expect(dispatch(eventName: "TaskCompleted", currentStatus: .working) == .needs_input)
    }

    @Test("Stop -> done")
    func stop_setsDone() {
        #expect(dispatch(eventName: "Stop", currentStatus: .working) == .done)
    }

    @Test("StopFailure -> done")
    func stopFailure_setsDone() {
        #expect(dispatch(eventName: "StopFailure", currentStatus: .working) == .done)
    }

    @Test("SessionEnd -> done")
    func sessionEnd_setsDone() {
        #expect(dispatch(eventName: "SessionEnd", currentStatus: .working) == .done)
    }

    @Test("Unknown event is ignored")
    func unknownEvent_ignored() {
        #expect(dispatch(eventName: "SomeNewEvent", currentStatus: .working) == nil)
    }

    @Test("UserPromptSubmit transitions from done to working")
    func userPromptSubmit_fromDone() {
        #expect(dispatch(eventName: "UserPromptSubmit", currentStatus: .done) == .working)
    }
}
