import Foundation
import Testing
@testable import FreeSign

struct AIIntegrationTests {
    @Test("AI context descriptions are deterministic and bounded")
    func contextDescriptionIsSafeForPrompts() {
        let context = TabContext(
            sourceView: "Apps",
            action: .analyze,
            summary: "Two visible apps.",
            details: [
                "visibleApps": ["Example A", "Example B"],
                "searchQuery": "example"
            ]
        )

        let description = context.promptPayloadDescription
        #expect(description.contains("- searchQuery: example"))
        #expect(description.contains("- tab: Apps"))
        #expect(description.contains("Example A, Example B"))
    }

    @Test("Anthropic formatter removes system turns and merges adjacent user turns")
    func anthropicFormatterProducesValidAlternatingTurns() {
        let messages: [AIMessage] = [
            .system("System context"),
            .user("First request"),
            .user("Additional visible context"),
            .assistant("First answer"),
            .assistant("More answer")
        ]

        let formatted = AIProviderMessageFormatter.anthropicMessages(from: messages)
        #expect(formatted.count == 2)
        #expect(formatted[0]["role"] == "user")
        #expect(formatted[0]["content"]?.contains("Additional visible context") == true)
        #expect(formatted[1]["role"] == "assistant")
        #expect(formatted[1]["content"]?.contains("More answer") == true)
    }

    @Test("Gemini formatter separates system instructions and maps assistant to model")
    func geminiFormatterProducesCorrectRoleShape() {
        let messages: [AIMessage] = [
            .system("Ground answers in the active tab."),
            .user("What is visible?"),
            .assistant("An imported IPA.")
        ]

        #expect(AIProviderMessageFormatter.systemPrompt(from: messages) == "Ground answers in the active tab.")
        let contents = AIProviderMessageFormatter.geminiContents(from: messages)
        #expect(contents.count == 2)
        #expect(contents[0]["role"] as? String == "user")
        #expect(contents[1]["role"] as? String == "model")
    }

    @Test("AI provider requests require HTTPS")
    func providerTransportRejectsCleartextHTTP() {
        #expect(throws: AIError.self) {
            try ProviderHTTPClient.makeRequest(
                urlString: "http://192.168.1.10:8080/v1/chat/completions",
                headers: [:],
                body: [:]
            )
        }

        let request = try? ProviderHTTPClient.makeRequest(
            urlString: "https://api.example.com/v1/chat/completions",
            headers: ["Content-Type": "application/json"],
            body: ["model": "example"]
        )
        #expect(request?.url?.scheme == "https")
    }

    @Test("Bundled provider defaults use secure endpoints and model IDs")
    func providerDefaultsAreReadyForConfiguration() {
        #expect(AIProviderType.openAICompatible.defaultEndpoint.hasPrefix("https://"))
        #expect(AIProviderType.gemini.defaultModel == "gemini-3.8-flash")
        #expect(AIProviderType.anthropic.defaultModel == "claude-sonnet-5")
        #expect(AIProviderType.localModel.defaultEndpoint.hasPrefix("https://"))
    }

    @Test("P12 and PFX files are recognized for the certificate import flow")
    func certificateFileTypesAreRecognized() {
        let p12 = URL(fileURLWithPath: "/tmp/signing-identity.p12")
        let pfx = URL(fileURLWithPath: "/tmp/signing-identity.pfx")
        #expect(FileImporter.detectFileType(from: p12)?.contentType == "com.rsa.pkcs-12")
        #expect(FileImporter.detectFileType(from: pfx)?.contentType == "com.rsa.pkcs-12")
    }
}
