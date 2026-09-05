import SwiftUI

// MARK: - Tab Context

/// A snapshot of the screen that opened the assistant. `details` contains only
/// user-visible, non-secret data so each provider receives the information that
/// actually appears in the active tab.
struct TabContext: AIContext {
    let sourceView: String
    let action: AIAction
    let summary: String
    let details: [String: Any]

    var payload: [String: Any] {
        ["tab": sourceView, "summary": summary].merging(details) { _, latest in latest }
    }

    enum CodingKeys: String, CodingKey {
        case sourceView, action, summary
    }

    init(sourceView: String, action: AIAction, summary: String, details: [String: Any] = [:]) {
        self.sourceView = sourceView
        self.action = action
        self.summary = summary
        self.details = details
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sourceView = try container.decode(String.self, forKey: .sourceView)
        action = try container.decode(AIAction.self, forKey: .action)
        summary = try container.decode(String.self, forKey: .summary)
        details = [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sourceView, forKey: .sourceView)
        try container.encode(action, forKey: .action)
        try container.encode(summary, forKey: .summary)
    }
}

// MARK: - Tab Assistant Button

/// Toolbar button that opens a persisted conversation scoped to the current tab.
struct TabAssistantButton: View {
    let sourceView: String
    let summary: String
    var details: [String: Any] = [:]

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "brain")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ThemeManager.shared.accentColor)
                .frame(minWidth: 32, minHeight: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Lab Assistant for \(sourceView)")
        .accessibilityIdentifier("tabAssistant.\(sourceView)")
        .sheet(isPresented: $isPresented) {
            TabAssistantView(sourceView: sourceView, summary: summary, details: details)
        }
    }
}

// MARK: - Tab Assistant View

/// Chat-style assistant available from every primary tab. The conversation is
/// preserved per tab while its system prompt is rebuilt with a fresh context
/// snapshot on each request.
struct TabAssistantView: View {
    let sourceView: String
    let summary: String
    var details: [String: Any] = [:]

    @Environment(\.dismiss) private var dismiss
    @State private var messages: [AIMessage] = []
    @State private var inputText = ""
    @State private var isGenerating = false

    private let quickActions: [AIAction] = [.explain, .summarize, .analyze, .suggest, .findIssues]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                contextBanner

                Divider().background(AppColors.cardBorder)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            if messages.isEmpty {
                                quickActionsGrid
                            } else {
                                ForEach(messages) { message in
                                    messageBubble(message)
                                        .id(message.id)
                                }
                                if isGenerating {
                                    HStack(spacing: 8) {
                                        ProgressView().tint(ThemeManager.shared.accentColor)
                                        Text("Thinking…")
                                            .font(AppFont.caption)
                                            .foregroundColor(AppColors.secondaryText)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 4)
                                    .id("thinking")
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .scrollContentBackground(.hidden)
                    .onChange(of: messages.count) { _ in
                        scrollToLatest(using: proxy)
                    }
                    .onChange(of: isGenerating) { _ in
                        scrollToLatest(using: proxy)
                    }
                }

                inputBar
            }
            .background(AppColors.background)
            .navigationTitle("Lab Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.secondaryText)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        messages.removeAll()
                        AIService.shared.clearConversation(for: sourceView)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(messages.isEmpty || isGenerating)
                    .accessibilityLabel("Clear \(sourceView) assistant conversation")
                }
            }
        }
        .task(id: sourceView) {
            messages = AIService.shared.messages(for: sourceView)
        }
    }

    // MARK: - Context banner

    private var contextBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundColor(ThemeManager.shared.accentColor)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text("Context: \(sourceView)")
                    .font(AppFont.caption.bold())
                    .foregroundColor(AppColors.primaryText)
                Text(summary)
                    .font(AppFont.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface.opacity(0.6))
    }

    // MARK: - Quick actions

    private var quickActionsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What would you like help with?")
                .font(AppFont.body.bold())
                .foregroundColor(AppColors.primaryText)

            ForEach(quickActions, id: \.self) { action in
                Button {
                    runQuickAction(action)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: action.icon)
                            .font(.system(size: 16))
                            .foregroundColor(ThemeManager.shared.accentColor)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.displayName)
                                .font(AppFont.body)
                                .foregroundColor(AppColors.primaryText)
                            Text(action.promptHint)
                                .font(AppFont.small)
                                .foregroundColor(AppColors.secondaryText)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.disabledText)
                    }
                    .padding(14)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.cardBorder, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isGenerating)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Messages

    @ViewBuilder
    private func messageBubble(_ message: AIMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .font(AppFont.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(ThemeManager.shared.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    messageTimestamp(message)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.content)
                        .font(AppFont.body)
                        .foregroundColor(AppColors.primaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(AppColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .textSelection(.enabled)
                    messageTimestamp(message)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }
        }
        .padding(.horizontal, 4)
    }

    private func messageTimestamp(_ message: AIMessage) -> some View {
        Text(message.timestamp.formatted(date: .omitted, time: .shortened))
            .font(AppFont.caption2)
            .foregroundColor(AppColors.disabledText)
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask about this tab…", text: $inputText, axis: .vertical)
                .font(AppFont.body)
                .foregroundColor(AppColors.primaryText)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.cardBorder, lineWidth: 1))
                .disabled(isGenerating)
                .submitLabel(.send)
                .onSubmit { sendQuestion() }

            Button { sendQuestion() } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(canSend ? ThemeManager.shared.accentColor : AppColors.disabledText)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel("Send assistant message")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Rectangle().fill(AppColors.surface.opacity(0.95)).ignoresSafeArea(edges: .bottom))
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    // MARK: - Actions

    private func runQuickAction(_ action: AIAction) {
        guard !isGenerating else { return }
        guard AISettings.shared.hasActiveProvider else {
            append(.assistant("Please configure and activate an AI provider in Settings → Lab Assistant to use this feature."))
            return
        }

        let history = messages
        append(.user("\(action.displayName) this tab"))
        isGenerating = true
        performRequest(action: action, question: nil, history: history)
    }

    private func sendQuestion() {
        let question = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isGenerating else { return }
        guard AISettings.shared.hasActiveProvider else {
            append(.assistant("Please configure and activate an AI provider in Settings → Lab Assistant to use this feature."))
            return
        }

        let history = messages
        inputText = ""
        append(.user(question))
        isGenerating = true
        performRequest(action: .custom, question: question, history: history)
    }

    private func performRequest(action: AIAction, question: String?, history: [AIMessage]) {
        Task {
            do {
                let context = TabContext(
                    sourceView: sourceView,
                    action: action,
                    summary: summary,
                    details: details
                )
                let stream = try await AIService.shared.respond(
                    to: action,
                    context: context,
                    userQuestion: question,
                    history: history
                )
                try await consume(stream)
            } catch {
                await fail(with: error)
            }
        }
    }

    private func consume(_ stream: AsyncThrowingStream<String, Error>) async throws {
        var fullResponse = ""
        for try await chunk in stream {
            fullResponse += chunk
        }
        guard !fullResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIError.emptyResponse
        }
        await MainActor.run {
            append(.assistant(fullResponse))
            isGenerating = false
        }
    }

    private func fail(with error: Error) async {
        await MainActor.run {
            append(.assistant("Unable to respond: \(error.localizedDescription)"))
            isGenerating = false
        }
    }

    private func append(_ message: AIMessage) {
        withAnimation(.easeOut(duration: 0.2)) {
            messages.append(message)
        }
        AIService.shared.saveConversation(
            messages: messages,
            sourceView: sourceView,
            contextSummary: summary
        )
    }

    private func scrollToLatest(using proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            if isGenerating {
                proxy.scrollTo("thinking", anchor: .bottom)
            } else if let id = messages.last?.id {
                proxy.scrollTo(id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Action presentation helpers

extension AIAction {
    var icon: String {
        switch self {
        case .explain: return "questionmark.circle"
        case .analyze: return "magnifyingglass"
        case .suggest: return "lightbulb"
        case .summarize: return "text.alignleft"
        case .findIssues: return "exclamationmark.triangle"
        case .custom: return "brain"
        }
    }

    var promptHint: String {
        switch self {
        case .explain: return "Explain what is shown and how it works"
        case .analyze: return "Analyze the visible items for problems or insights"
        case .suggest: return "Suggest practical next steps"
        case .summarize: return "Give a concise tab summary"
        case .findIssues: return "Look for warnings, gaps, or risky configuration"
        case .custom: return "Ask a custom question"
        }
    }
}

#Preview {
    TabAssistantButton(
        sourceView: "Library",
        summary: "5 imported apps, 2 signed apps, and 3 certificates.",
        details: ["selectedSection": "Imported"]
    )
}
