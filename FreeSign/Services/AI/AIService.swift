import Foundation
import SwiftUI

struct AIConversation: Identifiable, Codable {
    let id: UUID
    var title: String
    var sourceView: String
    var messages: [AIMessage]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "New Conversation",
        sourceView: String = "",
        messages: [AIMessage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.sourceView = sourceView
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Observable
final class AIService {
    static let shared = AIService()

    private(set) var activeProvider: AIProvider?
    private(set) var isGenerating = false

    private init() {
        refreshActiveProvider()
    }

    func refreshActiveProvider() {
        let settings = AISettings.shared
        guard let config = settings.activeProvider else {
            activeProvider = nil
            return
        }

        Task { [weak self] in
            let apiKey = await KeychainHelper.load(providerID: config.id)
            let provider = AIProviderFactory.make(config, apiKey: apiKey)
            await MainActor.run {
                self?.activeProvider = provider
            }
        }
    }

    func respond(
        to action: AIAction,
        context: any AIContext,
        userQuestion: String? = nil
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard let provider = activeProvider else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: AIError.missingAPIKey)
            }
        }

        isGenerating = true
        let messages = buildMessages(for: action, context: context, userQuestion: userQuestion)

        let upstream: AsyncThrowingStream<String, Error>
        do {
            upstream = try await provider.streamResponse(messages: messages, context: context)
        } catch {
            isGenerating = false
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: error)
            }
        }

        // Keep isGenerating true for the whole stream lifetime (the caller
        // consumes the stream after this function returns).
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await chunk in upstream {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
                await MainActor.run { self.isGenerating = false }
            }
        }
    }

    private func buildMessages(
        for action: AIAction,
        context: any AIContext,
        userQuestion: String?
    ) -> [AIMessage] {
        var messages: [AIMessage] = []

        let systemContent: String
        if action == .custom, let question = userQuestion, !question.isEmpty {
            systemContent = """
            You are a lab assistant integrated into FreeSign, an iOS sideloading workstation.
            The user asked: "\(question)"

            Current context:
            - Source: \(context.sourceView)
            - Summary: \(context.summary)

            Answer the user's question using the provided context. If the context doesn't \
            contain enough information, say so clearly rather than guessing.
            """
        } else {
            systemContent = """
            You are a lab assistant integrated into FreeSign, an iOS sideloading workstation.
            \(action.systemPromptSuffix)

            Current context:
            - Source: \(context.sourceView)
            - Action: \(action.displayName)
            - Summary: \(context.summary)
            - Payload keys: \(context.payload.keys.joined(separator: ", "))

            Ground your answer in the provided context. Be concise and technical.
            """
        }

        messages.append(.system(systemContent))

        let userContent: String
        if action == .custom, let question = userQuestion {
            userContent = question
        } else {
            userContent = context.summary
        }

        messages.append(.user(userContent, contextSummary: context.summary))

        return messages
    }
}
