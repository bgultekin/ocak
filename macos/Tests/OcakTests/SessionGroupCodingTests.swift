import Testing
import Foundation

// Local copy for testing (cannot import executable target).
// Mirrors Sources/Ocak/Models/SessionGroup.swift — keep in sync when the model changes.
private struct SessionGroup: Identifiable, Codable {
    var id: UUID
    var name: String
    var directory: String?
    var initialCommand: String?
    var order: Int
    var createdAt: Date
    var isCollapsed: Bool

    init(
        id: UUID = UUID(),
        name: String,
        directory: String? = nil,
        initialCommand: String? = nil,
        order: Int = 0,
        isCollapsed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.directory = directory
        self.initialCommand = initialCommand
        self.order = order
        self.createdAt = Date()
        self.isCollapsed = isCollapsed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        directory = try container.decodeIfPresent(String.self, forKey: .directory)
        initialCommand = try container.decodeIfPresent(String.self, forKey: .initialCommand)
        order = try container.decode(Int.self, forKey: .order)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isCollapsed = try container.decodeIfPresent(Bool.self, forKey: .isCollapsed) ?? false
    }
}

@Suite("SessionGroup — legacy-compatible decoding")
struct SessionGroupCodingTests {

    @Test("Legacy JSON without isCollapsed decodes with isCollapsed=false")
    func legacyDecode_missingIsCollapsed_defaultsFalse() throws {
        let legacyJSON = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "name": "Legacy Group",
          "order": 0,
          "createdAt": 760000000
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let group = try decoder.decode(SessionGroup.self, from: legacyJSON)

        #expect(group.name == "Legacy Group")
        #expect(group.isCollapsed == false)
        #expect(group.directory == nil)
        #expect(group.initialCommand == nil)
    }

    @Test("JSON with isCollapsed=true round-trips")
    func roundTrip_collapsedTrue() throws {
        let original = SessionGroup(name: "G", isCollapsed: true)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SessionGroup.self, from: data)
        #expect(decoded.isCollapsed == true)
        #expect(decoded.name == original.name)
        #expect(decoded.id == original.id)
    }

    @Test("JSON with isCollapsed=false round-trips")
    func roundTrip_collapsedFalse() throws {
        let original = SessionGroup(name: "G", isCollapsed: false)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SessionGroup.self, from: data)
        #expect(decoded.isCollapsed == false)
    }
}
