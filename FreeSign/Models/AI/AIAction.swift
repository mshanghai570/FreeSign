import Foundation

enum AIAction: String, Codable, CaseIterable, Identifiable {
    case explain
    case analyze
    case suggest
    case summarize
    case findIssues
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .explain: return "Explain"
        case .analyze: return "Analyze"
        case .suggest: return "Suggest Improvements"
        case .summarize: return "Summarize"
        case .findIssues: return "Find Issues"
        case .custom: return "Ask Anything..."
        }
    }

    var systemPromptSuffix: String {
        switch self {
        case .explain: return "Explain the following clearly and concisely."
        case .analyze: return "Analyze the following and report findings."
        case .suggest: return "Suggest improvements for the following."
        case .summarize: return "Summarize the following."
        case .findIssues: return "Find issues, risks, or anomalies in the following."
        case .custom: return ""
        }
    }
}
