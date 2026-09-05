import Foundation
import SwiftUI

@Observable
final class GeminiProvider: AIProvider {
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
                    let response = try ProviderHTTPClient.decode(GeminiResponse.self, from: data)
                    let text = response.candidates?
                        .first?.content.parts.compactMap(\.text).joined()
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
        var body: [String: Any] = [
            "contents": AIProviderMessageFormatter.geminiContents(from: messages),
            "generationConfig": ["maxOutputTokens": 1_024]
        ]
        if let systemPrompt = AIProviderMessageFormatter.systemPrompt(from: messages) {
            body["systemInstruction"] = ["parts": [["text": systemPrompt]]]
        }

        var base = configuration.endpointURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        let endpoint: String
        if base.hasSuffix(":generateContent") {
            endpoint = base
        } else if base.contains("/v1beta") {
            endpoint = ProviderHTTPClient.endpoint(base, path: "/models/\(configuration.modelName):generateContent")
        } else {
            endpoint = ProviderHTTPClient.endpoint(base, path: "/v1beta/models/\(configuration.modelName):generateContent")
        }

        return try ProviderHTTPClient.makeRequest(
            urlString: endpoint,
            headers: [
                "Content-Type": "application/json",
                "x-goog-api-key": apiKey ?? ""
            ],
            body: body
        )
    }
}

private struct GeminiResponse: Codable {
    struct Part: Codable { let text: String? }
    struct Content: Codable { let parts: [Part] }
    struct Candidate: Codable { let content: Content }
    let candidates: [Candidate]?
}
