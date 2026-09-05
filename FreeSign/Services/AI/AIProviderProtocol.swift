import Foundation

protocol AIProvider: Sendable {
    var id: UUID { get }
    var name: String { get }
    var configuration: AIProviderConfiguration { get }

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
    case providerError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No AI provider is configured. Add and activate one in Settings → Lab Assistant."
        case .invalidEndpoint:
            return "The provider endpoint URL is invalid. Check the URL in Settings → Lab Assistant."
        case .providerError(let message):
            return message
        }
    }
}

/// Shared transport used by every AI provider.
///
/// The key difference from a bare `URLSession` call: non-2xx responses are
/// parsed into a readable `AIError.providerError` (servers usually return
/// `{"error": {"message": "..."}}` or `{"message": "..."}`), and JSON decoding
/// failures include a snippet of the raw body so the user sees the real reason
/// instead of a generic "data couldn't be read" error.
enum ProviderHTTPClient {

    /// Builds a URLRequest without force-unwrapping the URL string.
    /// `headers` are applied as-is; `body` is JSON-serialized.
    static func makeRequest(
        urlString: String,
        method: String = "POST",
        headers: [String: String],
        body: [String: Any],
        timeout: TimeInterval = 120
    ) throws -> URLRequest {
        guard let url = URL(string: urlString) else {
            throw AIError.invalidEndpoint
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        request.timeoutInterval = timeout
        return request
    }

    /// Joins a base URL with a path fragment, avoiding duplicate slashes.
    /// e.g. `endpoint("http://host:8080", path: "/v1/chat/completions")`
    /// returns `http://host:8080/v1/chat/completions`, and the same input with
    /// a trailing-slash base returns the same result instead of `/v1/v1/...`.
    /// An empty `path` returns the base URL unchanged (no trailing slash).
    static func endpoint(_ base: String, path: String) -> String {
        var baseURL = base.trimmingCharacters(in: .whitespacesAndNewlines)
        if baseURL.hasSuffix("/") { baseURL.removeLast() }
        var pathComponent = path
        if pathComponent.hasPrefix("/") { pathComponent.removeFirst() }
        guard !pathComponent.isEmpty else { return baseURL }
        return "\(baseURL)/\(pathComponent)"
    }

    /// Performs the request and returns the raw data, throwing a readable
    /// `AIError.providerError` for non-2xx responses.
    static func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AIError.providerError("The provider returned an invalid response.")
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = Self.errorMessage(from: data, fallbackStatus: http.statusCode)
            throw AIError.providerError("Provider error (\(http.statusCode)): \(message)")
        }
        return data
    }

    /// Decodes the response, or throws a readable error that includes a snippet
    /// of the raw body when the payload doesn't match the expected shape.
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            let snippet = Self.responseSnippet(from: data)
            let detail = snippet.isEmpty ? "" : " Raw response: \(snippet)"
            throw AIError.providerError("The provider response could not be read.\(detail)")
        }
    }

    // MARK: - Private

    private static func errorMessage(from data: Data, fallbackStatus: Int) -> String {
        // Common error payload shapes:
        // {"error": {"message": "..."}}   (OpenAI / llama.cpp)
        // {"error": "..."}                (some servers)
        // {"message": "..."}              (Ollama)
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
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
        if !snippet.isEmpty { return snippet }
        return "The server returned HTTP \(fallbackStatus)."
    }

    private static func responseSnippet(from data: Data) -> String {
        // Only surface small bodies — never dump multi-MB payloads into chat.
        guard data.count <= 2_000,
              let text = String(data: data, encoding: .utf8) else { return "" }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return String(trimmed.prefix(500))
    }
}
