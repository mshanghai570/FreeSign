import Foundation

enum AIProviderType: String, Codable, CaseIterable, Identifiable {
    case openAICompatible
    case gemini
    case anthropic
    case localModel
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAICompatible: return "OpenAI-Compatible"
        case .gemini: return "Gemini"
        case .anthropic: return "Anthropic / Claude"
        case .localModel: return "Local Model"
        case .custom: return "Custom Provider"
        }
    }

    var icon: String {
        switch self {
        case .openAICompatible: return "brain"
        case .gemini: return "sparkles"
        case .anthropic: return "message.bubble"
        case .localModel: return "internaldrive"
        case .custom: return "server"
        }
    }

    var requiresEndpoint: Bool {
        switch self {
        case .openAICompatible, .gemini, .anthropic, .localModel, .custom: return true
        }
    }
    
    var defaultEndpoint: String {
        switch self {
        case .openAICompatible: return "https://api.openai.com/v1"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta"
        case .anthropic: return "https://api.anthropic.com/v1"
        case .localModel: return "https://localhost:8080"
        case .custom: return ""
        }
    }
    
    var defaultModel: String {
        switch self {
        // These defaults are editable in Lab Assistant. They use current,
        // stable text-capable model identifiers rather than retired aliases.
        case .openAICompatible: return "gpt-5.6-luna"
        case .gemini: return "gemini-3.8-flash"
        case .anthropic: return "claude-sonnet-5"
        case .localModel: return ""
        case .custom: return ""
        }
    }
}

struct AIProviderConfiguration: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var providerType: AIProviderType
    var endpointURL: String
    var modelName: String
    var isActive: Bool
    var createdAt: Date
    /// Path of an imported GGUF/MLX model file (see StorageManager.localModelFiles())
    /// used by the Local Model provider to reference the model served by the local server.
    var localModelPath: String?

    init(
        id: UUID = UUID(),
        name: String,
        providerType: AIProviderType,
        endpointURL: String,
        modelName: String,
        isActive: Bool = false,
        createdAt: Date = Date(),
        localModelPath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.providerType = providerType
        self.endpointURL = endpointURL
        self.modelName = modelName
        self.isActive = isActive
        self.createdAt = createdAt
        self.localModelPath = localModelPath
    }

    static let `default` = AIProviderConfiguration(
        name: "Default Provider",
        providerType: .openAICompatible,
        endpointURL: "",
        modelName: "",
        isActive: false
    )
}
