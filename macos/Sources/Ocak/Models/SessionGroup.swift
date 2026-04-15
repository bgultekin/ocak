import Foundation

struct SessionGroup: Identifiable, Codable {
    let id: UUID
    var name: String
    var directory: String?
    var initialCommand: String?
    var order: Int
    var createdAt: Date

    init(id: UUID = UUID(), name: String, directory: String? = nil, initialCommand: String? = nil, order: Int = 0) {
        self.id = id
        self.name = name
        self.directory = directory
        self.initialCommand = initialCommand
        self.order = order
        self.createdAt = Date()
    }
}
