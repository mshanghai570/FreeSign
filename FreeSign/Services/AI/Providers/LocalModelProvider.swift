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
        guard !configuration.endpointURL.isEmpty else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: AIError.providerError(
                    "Local Model provider is missing an endpoint URL. Enter your local inference server's address, e.g. http://192.168.1.10:8080"
                ))
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
            let systemPrompt = """
            You are a lab assistant for FreeSign, an iOS sideloading app.
            Context: \(context.sourceView) — \(context.summary)
            """
            apiMessages.append(["role": "system", "content": systemPrompt])
        }

        for msg in messages {
            apiMessages.append([
                "role": msg.role.rawValue,
                "content": msg.content
            ])
        }

        // Prefer the explicit model name; fall back to the imported model file's
        // name so the local server can resolve it (e.g. llama.cpp / Ollama aliases).
        var modelValue = configuration.modelName
        if modelValue.isEmpty, let path = configuration.localModelPath {
            modelValue = URL(fileURLWithPath: path).lastPathComponent
        }

        var body: [String: Any] = [
            "messages": apiMessages,
            "stream": false
        ]
        if !modelValue.isEmpty {
            body["model"] = modelValue
        }

        // Local inference servers expose the OpenAI-compatible API under /v1.
        // Accept a base URL (http://host:8080), one that already includes /v1
        // (Ollama, http://host:11434/v1), or one with a trailing slash — without
        // producing /v1/v1/... (which would 404 and surface as an error).
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
            body: body,
            timeout: 180
        )
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
