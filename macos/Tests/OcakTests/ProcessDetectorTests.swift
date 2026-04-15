import Testing
import Foundation

// Local copies for testing — Swift 5.9 executable targets cannot be imported by test targets

// MARK: - Local copy of ProcessDetector tree walk logic

private enum ProcessDetectorLocal {
    /// Testable pure function: BFS walk from root through children map, returns true if any descendant satisfies predicate.
    static func subtreeMatches(
        from root: pid_t,
        children: [pid_t: [pid_t]],
        predicate: (pid_t) -> Bool
    ) -> Bool {
        var queue: [pid_t] = children[root] ?? []
        while !queue.isEmpty {
            let pid = queue.removeFirst()
            if predicate(pid) { return true }
            queue.append(contentsOf: children[pid] ?? [])
        }
        return false
    }
}

// MARK: - Local mock types for SessionStore behavior testing

private struct MockSession {
    let id: UUID
    var isAgentRunning: Bool = false
}

@Observable
private final class MockSessionStore {
    var sessions: [MockSession]

    init(sessions: [MockSession]) {
        self.sessions = sessions
    }

    func updateAgentRunning(_ id: UUID, isRunning: Bool) {
        if let idx = sessions.firstIndex(where: { $0.id == id }) {
            sessions[idx].isAgentRunning = isRunning
        }
    }

    func restore() {
        for i in sessions.indices {
            sessions[i].isAgentRunning = false
        }
    }
}

// MARK: - Tests

@Suite("ProcessDetector — LABEL-01/02")
struct ProcessDetectorTests {

    // MARK: subtreeMatches tree walk tests

    @Test("subtreeMatchesReturnsFalseForEmptyChildren")
    func subtreeMatchesReturnsFalseForEmptyChildren() {
        // root has no children at all
        let children: [pid_t: [pid_t]] = [:]
        let result = ProcessDetectorLocal.subtreeMatches(from: 100, children: children) { _ in true }
        #expect(result == false)
    }

    @Test("subtreeMatchesReturnsTrueWhenDirectChildMatches")
    func subtreeMatchesReturnsTrueWhenDirectChildMatches() {
        // root 100 -> child 200 (matches)
        let children: [pid_t: [pid_t]] = [100: [200]]
        let result = ProcessDetectorLocal.subtreeMatches(from: 100, children: children) { $0 == 200 }
        #expect(result == true)
    }

    @Test("subtreeMatchesReturnsTrueWhenGrandchildMatches")
    func subtreeMatchesReturnsTrueWhenGrandchildMatches() {
        // root 100 -> child 200 -> grandchild 300 (matches)
        let children: [pid_t: [pid_t]] = [100: [200], 200: [300]]
        let result = ProcessDetectorLocal.subtreeMatches(from: 100, children: children) { $0 == 300 }
        #expect(result == true)
    }

    @Test("subtreeMatchesReturnsFalseWhenNoDescendantMatches")
    func subtreeMatchesReturnsFalseWhenNoDescendantMatches() {
        // Tree exists but no PID matches the predicate
        let children: [pid_t: [pid_t]] = [100: [200, 201], 200: [300]]
        let result = ProcessDetectorLocal.subtreeMatches(from: 100, children: children) { _ in false }
        #expect(result == false)
    }

    @Test("subtreeMatchesHandlesBranchingTrees")
    func subtreeMatchesHandlesBranchingTrees() {
        // root 100 -> [200, 201, 202]; 201 -> [301]; 301 matches
        let children: [pid_t: [pid_t]] = [
            100: [200, 201, 202],
            200: [300],
            201: [301],
        ]
        let result = ProcessDetectorLocal.subtreeMatches(from: 100, children: children) { $0 == 301 }
        #expect(result == true)
    }

    // MARK: updateAgentRunning mutation tests

    @Test("updateAgentRunningSetsIsAgentRunningToTrueOnCorrectSession")
    func updateAgentRunningSetsIsAgentRunningToTrueOnCorrectSession() {
        let idA = UUID()
        let idB = UUID()
        let store = MockSessionStore(sessions: [
            MockSession(id: idA, isAgentRunning: false),
            MockSession(id: idB, isAgentRunning: false),
        ])

        store.updateAgentRunning(idA, isRunning: true)

        #expect(store.sessions.first(where: { $0.id == idA })?.isAgentRunning == true)
        #expect(store.sessions.first(where: { $0.id == idB })?.isAgentRunning == false)
    }

    @Test("updateAgentRunningSetsIsAgentRunningToFalse")
    func updateAgentRunningSetsIsAgentRunningToFalse() {
        let id = UUID()
        let store = MockSessionStore(sessions: [
            MockSession(id: id, isAgentRunning: true)
        ])

        store.updateAgentRunning(id, isRunning: false)

        #expect(store.sessions.first(where: { $0.id == id })?.isAgentRunning == false)
    }

    @Test("restoreResetsIsAgentRunningToFalse")
    func restoreResetsIsAgentRunningToFalse() {
        let store = MockSessionStore(sessions: [
            MockSession(id: UUID(), isAgentRunning: true),
            MockSession(id: UUID(), isAgentRunning: true),
        ])

        store.restore()

        for session in store.sessions {
            #expect(session.isAgentRunning == false)
        }
    }

    // MARK: ThreadSession model tests (via MockSession)

    @Test("isAgentRunningDefaultsToFalse")
    func isAgentRunningDefaultsToFalse() {
        let session = MockSession(id: UUID())
        #expect(session.isAgentRunning == false)
    }

    @Test("threadSessionRoundTripsThroughJSONWithoutIsAgentRunning")
    func threadSessionRoundTripsThroughJSONWithoutIsAgentRunning() throws {
        // We test the CodingKeys exclusion pattern with a local type mirroring ThreadSession
        struct LocalSession: Codable {
            let id: UUID
            var name: String
            var isAgentRunning: Bool = false
            enum CodingKeys: String, CodingKey {
                case id, name  // isAgentRunning intentionally excluded
            }
        }

        let original = LocalSession(id: UUID(), name: "Test", isAgentRunning: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LocalSession.self, from: data)

        // After decode, isAgentRunning resets to default false (excluded from CodingKeys)
        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.isAgentRunning == false)
    }
}
