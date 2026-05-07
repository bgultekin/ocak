import Testing
import Foundation

// Local copies for testing (cannot import executable target)
private enum SessionStatus: Equatable {
    case new, working, needs_input, done
}

private struct MockSession {
    let id: UUID
    var status: SessionStatus
}

private func selectSession(
    _ id: UUID,
    sessions: inout [MockSession],
    activeID: inout UUID?
) {
    guard id != activeID else { return }
    activeID = id
    if let idx = sessions.firstIndex(where: { $0.id == id }) {
        let s = sessions[idx].status
        if s == .done || s == .needs_input {
            sessions[idx].status = .new
        }
    }
}

@Suite("selectSession — status clear on click")
struct SelectSessionTests {

    @Test("selecting a .done terminal clears its status to .new")
    func selectDoneTerminal_clearsToNew() {
        let a = MockSession(id: UUID(), status: .new)
        let b = MockSession(id: UUID(), status: .done)
        var sessions = [a, b]
        var activeID: UUID? = a.id
        selectSession(b.id, sessions: &sessions, activeID: &activeID)
        #expect(sessions[1].status == .new)
        #expect(activeID == b.id)
    }

    @Test("selecting a .needs_input terminal clears its status to .new")
    func selectNeedsInputTerminal_clearsToNew() {
        let a = MockSession(id: UUID(), status: .new)
        let b = MockSession(id: UUID(), status: .needs_input)
        var sessions = [a, b]
        var activeID: UUID? = a.id
        selectSession(b.id, sessions: &sessions, activeID: &activeID)
        #expect(sessions[1].status == .new)
        #expect(activeID == b.id)
    }

    @Test("re-clicking the active terminal is a no-op")
    func selectActiveTerminal_isNoOp() {
        let a = MockSession(id: UUID(), status: .done)
        var sessions = [a]
        var activeID: UUID? = a.id
        selectSession(a.id, sessions: &sessions, activeID: &activeID)
        #expect(sessions[0].status == .done)
        #expect(activeID == a.id)
    }

    @Test("selecting a .working terminal leaves its status unchanged")
    func selectWorkingTerminal_statusUnchanged() {
        let a = MockSession(id: UUID(), status: .new)
        let b = MockSession(id: UUID(), status: .working)
        var sessions = [a, b]
        var activeID: UUID? = a.id
        selectSession(b.id, sessions: &sessions, activeID: &activeID)
        #expect(sessions[1].status == .working)
    }

    @Test("selecting a .new terminal leaves its status unchanged")
    func selectNewTerminal_statusUnchanged() {
        let a = MockSession(id: UUID(), status: .done)
        let b = MockSession(id: UUID(), status: .new)
        var sessions = [a, b]
        var activeID: UUID? = a.id
        selectSession(b.id, sessions: &sessions, activeID: &activeID)
        #expect(sessions[1].status == .new)
        #expect(activeID == b.id)
    }

    @Test("only the newly selected terminal's status is cleared, not others")
    func selectTerminal_onlyClearsSelectedTerminal() {
        let a = MockSession(id: UUID(), status: .done)
        let b = MockSession(id: UUID(), status: .done)
        let c = MockSession(id: UUID(), status: .done)
        var sessions = [a, b, c]
        var activeID: UUID? = a.id
        selectSession(b.id, sessions: &sessions, activeID: &activeID)
        #expect(sessions[0].status == .done)
        #expect(sessions[1].status == .new)
        #expect(sessions[2].status == .done)
    }
}
