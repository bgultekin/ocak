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
    var name: String
    var status: SessionStatus
}

private func renameSession(_ id: UUID, name: String, in sessions: inout [MockSession]) {
    if let idx = sessions.firstIndex(where: { $0.id == id }) {
        sessions[idx].name = name
    }
}

private func removeSession(_ id: UUID, from sessions: inout [MockSession], activeID: inout UUID?) {
    guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
    sessions.remove(at: idx)
    if activeID == id {
        if idx > 0, idx - 1 < sessions.count {
            activeID = sessions[idx - 1].id
        } else if idx < sessions.count {
            activeID = sessions[idx].id
        } else {
            activeID = sessions.first?.id
        }
    }
}

@Suite("Session Lifecycle — SESS-01, SESS-02, SESS-03")
struct SessionLifecycleTests {

    // MARK: - renameSession

    @Test("renameSession updates name when session exists")
    func renameSession_updatesNameWhenSessionExists() {
        var sessions: [MockSession] = [
            MockSession(id: UUID(), name: "Session 1", status: .new),
        ]
        renameSession(sessions[0].id, name: "My Project", in: &sessions)
        #expect(sessions[0].name == "My Project")
    }

    @Test("renameSession is no-op for unknown UUID")
    func renameSession_isNoOpForUnknownUUID() {
        var sessions: [MockSession] = [
            MockSession(id: UUID(), name: "Session 1", status: .new),
        ]
        let originalName = sessions[0].name
        renameSession(UUID(), name: "Phantom", in: &sessions)
        #expect(sessions[0].name == originalName)
    }

    // MARK: - removeSession adjacent selection

    @Test("removeSession selects previous session when deleting middle")
    func removeSession_selectsPreviousWhenDeletingMiddle() {
        let a = MockSession(id: UUID(), name: "A", status: .new)
        let b = MockSession(id: UUID(), name: "B", status: .new)
        let c = MockSession(id: UUID(), name: "C", status: .new)
        var sessions: [MockSession] = [a, b, c]
        var activeID: UUID? = b.id
        removeSession(b.id, from: &sessions, activeID: &activeID)
        #expect(activeID == a.id)
    }

    @Test("removeSession selects next session when deleting first")
    func removeSession_selectsNextWhenDeletingFirst() {
        let a = MockSession(id: UUID(), name: "A", status: .new)
        let b = MockSession(id: UUID(), name: "B", status: .new)
        let c = MockSession(id: UUID(), name: "C", status: .new)
        var sessions: [MockSession] = [a, b, c]
        var activeID: UUID? = a.id
        removeSession(a.id, from: &sessions, activeID: &activeID)
        #expect(activeID == b.id)
    }

    @Test("removeSession selects nil when deleting last remaining")
    func removeSession_selectsNilWhenDeletingLastRemaining() {
        let a = MockSession(id: UUID(), name: "A", status: .new)
        var sessions: [MockSession] = [a]
        var activeID: UUID? = a.id
        removeSession(a.id, from: &sessions, activeID: &activeID)
        #expect(activeID == nil)
    }

    @Test("removeSession does not change activeID when deleting non-active")
    func removeSession_doesNotChangeActiveIDWhenDeletingNonActive() {
        let a = MockSession(id: UUID(), name: "A", status: .new)
        let b = MockSession(id: UUID(), name: "B", status: .new)
        let c = MockSession(id: UUID(), name: "C", status: .new)
        var sessions: [MockSession] = [a, b, c]
        var activeID: UUID? = a.id
        removeSession(c.id, from: &sessions, activeID: &activeID)
        #expect(activeID == a.id)
    }
}
