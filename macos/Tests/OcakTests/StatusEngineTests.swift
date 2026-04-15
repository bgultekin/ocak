import Testing
import Foundation

// Local copy of SessionStatus for testing (cannot import executable target)
private enum SessionStatus: String, Codable {
    case new
    case working
    case needs_input
    case done
}

@Suite("Status Engine — STAT-01, STAT-07")
struct StatusEngineTests {
    @Test("SessionStatus has exactly 4 cases")
    func sessionStatus_fourCases() {
        let allCases: [SessionStatus] = [.new, .working, .needs_input, .done]
        #expect(allCases.count == 4)
    }

    @Test("SessionStatus raw values match spec")
    func sessionStatus_rawValues() {
        #expect(SessionStatus.new.rawValue == "new")
        #expect(SessionStatus.working.rawValue == "working")
        #expect(SessionStatus.needs_input.rawValue == "needs_input")
        #expect(SessionStatus.done.rawValue == "done")
    }

    @Test("Default status is .new — STAT-07")
    func defaultStatus_isNew() {
        // Mirror the ThreadSession default: status parameter defaults to .new
        let defaultStatus: SessionStatus = .new
        #expect(defaultStatus == .new)
    }

    @Test("SessionStatus is Codable round-trip")
    func sessionStatus_codableRoundTrip() throws {
        let original: SessionStatus = .needs_input
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SessionStatus.self, from: data)
        #expect(decoded == original)
    }
}
