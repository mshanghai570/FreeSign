import Foundation
import SwiftUI

@Observable
final class OpenAICompatibleProvider: AIProvider {
    let id: UUID
    let name: String
    let configuration: AIProviderConfiguration

    private let apiKey: String?

    init(configuration: AIProviderConfiguration, apiKey: String? = nil) {
        self.id = configuration.id
        self.name = configuration.name
        self.configuration = configuration
        self.apiKey = apiKey
    }

    func streamResponse(
        messages: [AIMessage],
        context: AIContext?
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: AIError.missingAPIKey)
            }
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try buildRequest(messages: messages, context: context)
                    let data = try await ProviderHTTPClient.perform(request)

                    let response = try ProviderHTTPClient.decode(OpenAIResponse.self, from: data)
                    let text = response.choices.first?.message.content ?? ""

                    continuation.yield(text)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func buildRequest(messages: [AIMessage], context: AIContext?) throws -> URLRequest {
        var apiMessages: [[String: Any]] = []

        if let context = context {
            let systemPrompt = buildSystemPrompt(for: context)
            apiMessages.append(["role": "system", "content": systemPrompt])
        }

        for msg in messages {
            apiMessages.append([
                "role": msg.role.rawValue,
                "content": msg.content
            ])
        }

        let body: [String: Any] = [
            "model": configuration.modelName,
            "messages": apiMessages,
            "stream": false
        ]

        // The chat completions endpoint lives under /v1. Accept a base URL
        // (http://host:8080), one that already includes /v1 (OpenAI, Ollama,
        // LM Studio), or a trailing slash — without producing /v1/v1/...
        // (which would 404 and surface as a provider error in chat).
        var baseURL = configuration.endpointURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if baseURL.hasSuffix("/") { baseURL.removeLast() }
        let path: String
        if baseURL.hasSuffix("/v1") {
            path = "/chat/completions"
        } else {
            path = "/v1/chat/completions"
        }
        let endpoint = ProviderHTTPClient.endpoint(baseURL, path: path)

        return try ProviderHTTPClient.makeRequest(
            urlString: endpoint,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(apiKey ?? "")"
            ],
            body: body
        )
    }

    private func buildSystemPrompt(for context: AIContext) -> String {
        """
        You are a lab assistant for FreeSign, an iOS sideloading app.
        The user is interacting with: \(context.sourceView).
        User action: \(context.action.displayName).
        Context summary: \(context.summary).

        Answer concisely. If the user asks about IPA signing, certificates, or app \
        modification, ground your answer in the provided context. If the context is \
        insufficient, say so rather than guessing.
        """
    }
}

private struct OpenAIResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}
