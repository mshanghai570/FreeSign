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

                    let response = try ProviderHTTPClient.decode(GeminiResponse.self, from: data)
                    let text = response.candidates?.first?.content.parts.first?.text ?? ""

                    continuation.yield(text)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func buildRequest(messages: [AIMessage], context: AIContext?) throws -> URLRequest {
        var contents: [[String: Any]] = []

        if let context = context {
            let systemPrompt = """
            You are a lab assistant for FreeSign, an iOS sideloading app.
            Context: \(context.sourceView) — \(context.summary)
            """
            contents.append(["role": "user", "parts": [["text": systemPrompt]]])
        }

        for msg in messages {
            contents.append([
                "role": msg.role == .assistant ? "model" : "user",
                "parts": [["text": msg.content]]
            ])
        }

        let body: [String: Any] = [
            "contents": contents
        ]

        let endpoint = ProviderHTTPClient.endpoint(
            configuration.endpointURL,
            path: "/v1beta/models/\(configuration.modelName):generateContent"
        )
        return try ProviderHTTPClient.makeRequest(
            urlString: endpoint,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(apiKey ?? "")"
            ],
            body: body
        )
    }
}

private struct GeminiResponse: Codable {
    struct Part: Codable {
        let text: String
    }
    struct Content: Codable {
        let parts: [Part]
    }
    struct Candidate: Codable {
        let content: Content
    }
    let candidates: [Candidate]?
}
