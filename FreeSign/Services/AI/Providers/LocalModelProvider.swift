import Foundation
import SwiftUI

@Observable
final class LocalModelProvider: AIProvider {
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
        guard !configuration.endpointURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: AIError.providerError(
                    "Local Model provider is missing an endpoint URL. Enter an HTTPS OpenAI-compatible local inference server address."
                ))
            }
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let data = try await ProviderHTTPClient.perform(buildRequest(messages: messages))
                    let response = try ProviderHTTPClient.decode(LocalOpenAIResponse.self, from: data)
                    let text = response.choices.first?.message.content?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    guard !text.isEmpty else { throw AIError.emptyResponse }
                    continuation.yield(text)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func buildRequest(messages: [AIMessage]) throws -> URLRequest {
        var model = configuration.modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        if model.isEmpty, let localModelPath = configuration.localModelPath {
            model = URL(fileURLWithPath: localModelPath).lastPathComponent
        }

        var body: [String: Any] = [
            "messages": AIProviderMessageFormatter.openAIChatMessages(from: messages),
            "stream": false
        ]
        if !model.isEmpty { body["model"] = model }

        var base = configuration.endpointURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        let endpoint: String
        if base.hasSuffix("/chat/completions") {
            endpoint = base
        } else if base.hasSuffix("/v1") {
            endpoint = ProviderHTTPClient.endpoint(base, path: "/chat/completions")
        } else {
            endpoint = ProviderHTTPClient.endpoint(base, path: "/v1/chat/completions")
        }

        var headers = ["Content-Type": "application/json"]
        if let apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !apiKey.isEmpty {
            headers["Authorization"] = "Bearer \(apiKey)"
        }
        return try ProviderHTTPClient.makeRequest(
            urlString: endpoint,
            headers: headers,
            body: body,
            timeout: 180
        )
    }
}

private struct LocalOpenAIResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable { let content: String? }
        let message: Message
    }
    let choices: [Choice]
}
