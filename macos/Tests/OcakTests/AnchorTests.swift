import Testing
import Foundation

// Local copy of SessionStatus for testing (cannot import executable target)
private enum SessionStatus: String, Codable {
    case new
    case working
    case needs_input
    case done
}

private struct MockSession {
    let id: UUID
    var status: SessionStatus
}

private func hasWorking(_ sessions: [MockSession]) -> Bool {
    sessions.contains { $0.status == .working }
}

private func needsInputCount(_ sessions: [MockSession]) -> Int {
    sessions.filter { $0.status == .needs_input }.count
}

@Suite("Anchor Aggregate Status — ANCH-01, ANCH-03")
struct AnchorTests {

    // MARK: - hasWorking

    @Test("hasWorking returns true when at least one session is .working")
    func hasWorking_returnsTrueWhenOneWorking() {
        let sessions: [MockSession] = [
            MockSession(id: UUID(), status: .new),
            MockSession(id: UUID(), status: .working),
            MockSession(id: UUID(), status: .done),
        ]
        #expect(hasWorking(sessions) == true)
    }

    @Test("hasWorking returns false when no sessions are .working")
    func hasWorking_returnsFalseWhenNoneWorking() {
        let sessions: [MockSession] = [
            MockSession(id: UUID(), status: .new),
            MockSession(id: UUID(), status: .needs_input),
            MockSession(id: UUID(), status: .done),
        ]
        #expect(hasWorking(sessions) == false)
    }

    @Test("hasWorking returns false when sessions array is empty")
    func hasWorking_returnsFalseWhenEmpty() {
        let sessions: [MockSession] = []
        #expect(hasWorking(sessions) == false)
    }

    // MARK: - needsInputCount

    @Test("needsInputCount returns exact count of sessions with .needs_input status")
    func needsInputCount_returnsExactCount() {
        let sessions: [MockSession] = [
            MockSession(id: UUID(), status: .needs_input),
            MockSession(id: UUID(), status: .needs_input),
            MockSession(id: UUID(), status: .working),
        ]
        #expect(needsInputCount(sessions) == 2)
    }

    @Test("needsInputCount returns 0 when no sessions need input")
    func needsInputCount_returnsZeroWhenNoneNeedInput() {
        let sessions: [MockSession] = [
            MockSession(id: UUID(), status: .new),
            MockSession(id: UUID(), status: .working),
            MockSession(id: UUID(), status: .done),
        ]
        #expect(needsInputCount(sessions) == 0)
    }

    @Test("needsInputCount returns 0 when sessions array is empty")
    func needsInputCount_returnsZeroWhenEmpty() {
        let sessions: [MockSession] = []
        #expect(needsInputCount(sessions) == 0)
    }

    // MARK: - Mixed scenario

    @Test("Mixed: 2 working, 3 needs_input, 1 done — hasWorking true and needsInputCount 3")
    func mixedScenario_hasWorkingTrueAndNeedsInputCountThree() {
        let sessions: [MockSession] = [
            MockSession(id: UUID(), status: .working),
            MockSession(id: UUID(), status: .working),
            MockSession(id: UUID(), status: .needs_input),
            MockSession(id: UUID(), status: .needs_input),
            MockSession(id: UUID(), status: .needs_input),
            MockSession(id: UUID(), status: .done),
        ]
        #expect(hasWorking(sessions) == true)
        #expect(needsInputCount(sessions) == 3)
    }
}
