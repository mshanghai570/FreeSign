import Foundation

protocol AIProvider: Sendable {
    var id: UUID { get }
    var name: String { get }
    var configuration: AIProviderConfiguration { get }

    /// Providers return an async stream so the UI has one consistent response path
    /// even when a provider only supports non-streaming completions.
    func streamResponse(
        messages: [AIMessage],
        context: AIContext?
    ) async throws -> AsyncThrowingStream<String, Error>
}

enum AIProviderFactory {
    static func make(_ config: AIProviderConfiguration, apiKey: String? = nil) -> AIProvider? {
        switch config.providerType {
        case .openAICompatible:
            return OpenAICompatibleProvider(configuration: config, apiKey: apiKey)
        case .gemini:
            return GeminiProvider(configuration: config, apiKey: apiKey)
        case .anthropic:
            return AnthropicProvider(configuration: config, apiKey: apiKey)
        case .localModel:
            return LocalModelProvider(configuration: config, apiKey: apiKey)
        case .custom:
            return OpenAICompatibleProvider(configuration: config, apiKey: apiKey)
        }
    }
}

enum AIError: LocalizedError {
    case missingAPIKey
    case invalidEndpoint
    case insecureEndpoint
    case emptyResponse
    case providerError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key is available for the active provider. Add one in Settings → Lab Assistant."
        case .invalidEndpoint:
            return "The provider endpoint URL is invalid. Check the URL in Settings → Lab Assistant."
        case .insecureEndpoint:
            return "FreeSign requires an HTTPS endpoint for AI providers. Configure TLS on the provider or local inference server."
        case .emptyResponse:
            return "The provider completed the request but did not return any text. Check the selected model and provider settings."
        case .providerError(let message):
            return message
        }
    }
}

/// Translates the app's provider-neutral conversation format to the role shapes
/// required by each remote API. System messages are deliberately separated for
/// Anthropic and Gemini, whose APIs do not accept OpenAI's `system` role inline.
enum AIProviderMessageFormatter {
    static func systemPrompt(from messages: [AIMessage]) -> String? {
        let prompt = messages
            .filter { $0.role == .system }
            .map(\.content)
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return prompt.isEmpty ? nil : prompt
    }

    static func openAIChatMessages(from messages: [AIMessage]) -> [[String: String]] {
        messages
            .filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { ["role": $0.role.rawValue, "content": $0.content] }
    }

    static func anthropicMessages(from messages: [AIMessage]) -> [[String: String]] {
        groupedMessages(from: messages) { message in
            switch message.role {
            case .assistant: return "assistant"
            case .user: return "user"
            case .system: return nil
            }
        }
    }

    static func geminiContents(from messages: [AIMessage]) -> [[String: Any]] {
        groupedMessages(from: messages) { message in
            switch message.role {
            case .assistant: return "model"
            case .user: return "user"
            case .system: return nil
            }
        }
        .map { ["role": $0["role"] ?? "user", "parts": [["text": $0["content"] ?? ""]]] }
    }

    /// Gemini and Anthropic require alternating turns. Consecutive messages with
    /// the same role are combined so a context-rich multi-turn conversation stays
    /// valid after retries and quick actions.
    private static func groupedMessages(
        from messages: [AIMessage],
        role: (AIMessage) -> String?
    ) -> [[String: String]] {
        var grouped: [[String: String]] = []
        for message in messages {
            guard let apiRole = role(message) else { continue }
            let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { continue }

            if grouped.last?["role"] == apiRole {
                grouped[grouped.count - 1]["content", default: ""] += "\n\n\(content)"
            } else {
                grouped.append(["role": apiRole, "content": content])
            }
        }
        return grouped
    }
}

/// Shared transport used by every AI provider.
///
/// Non-success responses are decoded to readable `AIError.providerError` values,
/// so the chat reports a useful model, authorization, or endpoint error instead
/// of a generic JSON-decoding failure.
enum ProviderHTTPClient {
    static func makeRequest(
        urlString: String,
        method: String = "POST",
        headers: [String: String],
        body: [String: Any],
        timeout: TimeInterval = 120
    ) throws -> URLRequest {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              url.host != nil
        else {
            throw AIError.invalidEndpoint
        }
        guard scheme == "https" else {
            throw scheme == "http" ? AIError.insecureEndpoint : AIError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        return request
    }

    /// Joins a base URL with a path fragment, avoiding duplicate slashes.
    static func endpoint(_ base: String, path: String) -> String {
        var baseURL = base.trimmingCharacters(in: .whitespacesAndNewlines)
        while baseURL.hasSuffix("/") { baseURL.removeLast() }
        var pathComponent = path
        while pathComponent.hasPrefix("/") { pathComponent.removeFirst() }
        guard !pathComponent.isEmpty else { return baseURL }
        return "\(baseURL)/\(pathComponent)"
    }

    static func perform(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw AIError.providerError("The provider returned an invalid response.")
            }
            guard (200..<300).contains(http.statusCode) else {
                let message = errorMessage(from: data, fallbackStatus: http.statusCode)
                throw AIError.providerError("Provider error (\(http.statusCode)): \(message)")
            }
            return data
        } catch let error as AIError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError {
            throw AIError.providerError(networkMessage(for: error))
        } catch {
            throw AIError.providerError("Unable to reach the provider: \(error.localizedDescription)")
        }
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            let snippet = responseSnippet(from: data)
            let detail = snippet.isEmpty ? "" : " Raw response: \(snippet)"
            throw AIError.providerError("The provider response could not be read.\(detail)")
        }
    }

    private static func networkMessage(for error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet:
            return "No internet connection is available."
        case .timedOut:
            return "The provider request timed out. Check the endpoint and selected model."
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "The provider host could not be reached. Check the endpoint URL and network access."
        case .secureConnectionFailed, .serverCertificateUntrusted:
            return "The provider's secure connection could not be verified."
        default:
            return "Unable to reach the provider: \(error.localizedDescription)"
        }
    }

    private static func errorMessage(from data: Data, fallbackStatus: Int) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String, !message.isEmpty {
                return message
            }
            if let message = json["error"] as? String, !message.isEmpty {
                return message
            }
            if let message = json["message"] as? String, !message.isEmpty {
                return message
            }
        }
        let snippet = responseSnippet(from: data)
        return snippet.isEmpty ? "The server returned HTTP \(fallbackStatus)." : snippet
    }

    private static func responseSnippet(from data: Data) -> String {
        guard data.count <= 2_000,
              let text = String(data: data, encoding: .utf8) else { return "" }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(500))
    }
}
