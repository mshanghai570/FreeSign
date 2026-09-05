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
        guard let apiKey, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return AsyncThrowingStream { $0.finish(throwing: AIError.missingAPIKey) }
        }
        guard !configuration.modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return AsyncThrowingStream { $0.finish(throwing: AIError.providerError("Select a model name for the active provider.")) }
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let data = try await ProviderHTTPClient.perform(buildRequest(messages: messages))
                    let response = try ProviderHTTPClient.decode(AnthropicResponse.self, from: data)
                    let text = response.content
                        .compactMap(\.text)
                        .joined()
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { throw AIError.emptyResponse }
                    continuation.yield(text)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func buildRequest(messages: [AIMessage]) throws -> URLRequest {
        var body: [String: Any] = [
            "model": configuration.modelName.trimmingCharacters(in: .whitespacesAndNewlines),
            "messages": AIProviderMessageFormatter.anthropicMessages(from: messages),
            "max_tokens": 1_024
        ]
        if let systemPrompt = AIProviderMessageFormatter.systemPrompt(from: messages) {
            body["system"] = systemPrompt
        }

        var baseURL = configuration.endpointURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while baseURL.hasSuffix("/") { baseURL.removeLast() }
        let endpoint: String
        if baseURL.hasSuffix("/v1/messages") {
            endpoint = baseURL
        } else if baseURL.hasSuffix("/v1") {
            endpoint = ProviderHTTPClient.endpoint(baseURL, path: "/messages")
        } else {
            endpoint = ProviderHTTPClient.endpoint(baseURL, path: "/v1/messages")
        }

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
        let type: String?
        let text: String?
    }
    let content: [ContentBlock]
}
