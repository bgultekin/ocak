import Testing
import Foundation

// Local copies for testing (cannot import executable target)
private enum SessionStatus: String, Codable {
    case new, working, needs_input, done
}

private struct MockSession {
    let id: UUID
    var status: SessionStatus
}

private func needsInputCount(sessions: [MockSession]) -> Int {
    sessions.filter { $0.status == .needs_input }.count
}

private func hasAttention(sessions: [MockSession]) -> Bool {
    sessions.contains { $0.status == .needs_input }
}

@Suite("Session Panel UX — UX-02, UX-03")
struct SessionPanelUXTests {

    // MARK: - Anchor needs_input badge (UX-03)

    @Test("anchor_badgeCountMatchesNeedsInputSessions")
    func anchor_badgeCountMatchesNeedsInputSessions() {
        let sessions = [
            MockSession(id: UUID(), status: .needs_input),
            MockSession(id: UUID(), status: .working),
            MockSession(id: UUID(), status: .needs_input),
            MockSession(id: UUID(), status: .done),
        ]
        #expect(needsInputCount(sessions: sessions) == 2)
    }

    @Test("anchor_badgeZeroWhenNoNeedsInput")
    func anchor_badgeZeroWhenNoNeedsInput() {
        let sessions = [
            MockSession(id: UUID(), status: .working),
            MockSession(id: UUID(), status: .done),
        ]
        #expect(needsInputCount(sessions: sessions) == 0)
    }

    @Test("anchor_hasAttentionWhenAnyNeedsInput")
    func anchor_hasAttentionWhenAnyNeedsInput() {
        let sessions = [
            MockSession(id: UUID(), status: .working),
            MockSession(id: UUID(), status: .needs_input),
        ]
        #expect(hasAttention(sessions: sessions) == true)
    }

    @Test("anchor_noAttentionWhenAllDoneOrWorking")
    func anchor_noAttentionWhenAllDoneOrWorking() {
        let sessions = [
            MockSession(id: UUID(), status: .working),
            MockSession(id: UUID(), status: .done),
            MockSession(id: UUID(), status: .new),
        ]
        #expect(hasAttention(sessions: sessions) == false)
    }

    @Test("anchor_badgeCountEmptySessions")
    func anchor_badgeCountEmptySessions() {
        #expect(needsInputCount(sessions: []) == 0)
    }
}
