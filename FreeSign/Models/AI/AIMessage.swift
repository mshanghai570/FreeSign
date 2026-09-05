import Foundation

enum AIRole: String, Codable {
    case system
    case user
    case assistant
}

struct AIMessage: Identifiable, Codable, Equatable {
    let id: UUID
    var role: AIRole
    var content: String
    var timestamp: Date
    var contextSummary: String?

    init(
        id: UUID = UUID(),
        role: AIRole,
        content: String,
        timestamp: Date = Date(),
        contextSummary: String? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.contextSummary = contextSummary
    }

    static func system(_ content: String) -> AIMessage {
        AIMessage(role: .system, content: content)
    }

    static func user(_ content: String, contextSummary: String? = nil) -> AIMessage {
        AIMessage(role: .user, content: content, contextSummary: contextSummary)
    }

    static func assistant(_ content: String) -> AIMessage {
        AIMessage(role: .assistant, content: content)
    }
}
