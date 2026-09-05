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
                    let response = try ProviderHTTPClient.decode(OpenAIResponse.self, from: data)
                    let text = response.choices.first?.message.content?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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
        let endpoint = chatCompletionsEndpoint(from: configuration.endpointURL)
        let body: [String: Any] = [
            "model": configuration.modelName.trimmingCharacters(in: .whitespacesAndNewlines),
            "messages": AIProviderMessageFormatter.openAIChatMessages(from: messages),
            "stream": false
        ]
        return try ProviderHTTPClient.makeRequest(
            urlString: endpoint,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(apiKey ?? "")"
            ],
            body: body
        )
    }

    private func chatCompletionsEndpoint(from configuredEndpoint: String) -> String {
        var base = configuredEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        if base.hasSuffix("/chat/completions") { return base }
        return base.hasSuffix("/v1")
            ? ProviderHTTPClient.endpoint(base, path: "/chat/completions")
            : ProviderHTTPClient.endpoint(base, path: "/v1/chat/completions")
    }
}

private struct OpenAIResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String?
        }
        let message: Message
    }
    let choices: [Choice]
}
