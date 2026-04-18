import Foundation

struct SessionGroup: Identifiable, Codable {
    let id: UUID
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

    // Custom decoder so legacy UserDefaults data (without isCollapsed) still loads.
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
