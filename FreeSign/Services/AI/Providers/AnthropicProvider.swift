import Foundation
import SwiftUI

@Observable
final class AnthropicProvider: AIProvider {
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

                    let response = try ProviderHTTPClient.decode(AnthropicResponse.self, from: data)
                    let text = response.content?.first?.text ?? ""

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
            let systemPrompt = """
            You are a lab assistant for FreeSign, an iOS sideloading app.
            Context: \(context.sourceView) — \(context.summary)
            """
            apiMessages.append(["role": "user", "content": systemPrompt])
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
            "max_tokens": 1024
        ]

        // Anthropic's Messages API lives at /v1/messages. Accept a base URL
        // (https://api.anthropic.com) or a full endpoint, without producing
        // /v1/v1/... (which would 404 and surface as a provider error).
        var baseURL = configuration.endpointURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if baseURL.hasSuffix("/") { baseURL.removeLast() }
        let path: String
        if baseURL.hasSuffix("/v1/messages") {
            path = ""
        } else if baseURL.hasSuffix("/v1") {
            path = "/messages"
        } else {
            path = "/v1/messages"
        }
        let endpoint = ProviderHTTPClient.endpoint(baseURL, path: path)

        return try ProviderHTTPClient.makeRequest(
            urlString: endpoint,
            headers: [
                "Content-Type": "application/json",
                "x-api-key": apiKey ?? "",
                "anthropic-version": "2023-06-01"
            ],
            body: body
        )
    }
}

private struct AnthropicResponse: Codable {
    struct ContentBlock: Codable {
        let text: String
    }
    let content: [ContentBlock]?
}
