import SwiftUI

// MARK: - Tab Context

/// Lightweight `AIContext` that describes what is currently on screen in a tab.
struct TabContext: AIContext {
    let sourceView: String
    let action: AIAction
    let summary: String

    var payload: [String: Any] {
        ["tab": sourceView]
    }

    enum CodingKeys: String, CodingKey {
        case sourceView, action, summary
    }

    init(sourceView: String, action: AIAction, summary: String) {
        self.sourceView = sourceView
        self.action = action
        self.summary = summary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sourceView = try container.decode(String.self, forKey: .sourceView)
        action = try container.decode(AIAction.self, forKey: .action)
        summary = try container.decode(String.self, forKey: .summary)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sourceView, forKey: .sourceView)
        try container.encode(action, forKey: .action)
        try container.encode(summary, forKey: .summary)
    }
}

// MARK: - Tab Assistant Button

/// Toolbar button that opens the Lab Assistant scoped to the current tab.
/// Drop it into any tab's toolbar:
///
///     .toolbar {
///         ToolbarItem(placement: .primaryAction) {
///             TabAssistantButton(sourceView: "Library", summary: librarySummary)
///         }
///     }
struct TabAssistantButton: View {
    let sourceView: String
    let summary: String

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "brain")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ThemeManager.shared.accentColor)
        }
        .accessibilityLabel("Lab Assistant")
        .sheet(isPresented: $isPresented) {
            TabAssistantView(sourceView: sourceView, summary: summary)
        }
    }
}

// MARK: - Tab Assistant View

/// Chat-style assistant available from every tab. Shows quick actions that
/// explain / summarize / analyze the current page, plus a free-form question
/// field. All requests are grounded in `summary` so answers stay relevant.
struct TabAssistantView: View {
    let sourceView: String
    let summary: String

    @Environment(\.dismiss) private var dismiss
    @State private var messages: [AIMessage] = []
    @State private var inputText = ""
    @State private var isGenerating = false

    private let quickActions: [AIAction] = [.explain, .summarize, .analyze, .suggest, .findIssues]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                contextBanner

                Divider()
                    .background(AppColors.cardBorder)

                ScrollView {
                    VStack(spacing: 12) {
                        if messages.isEmpty {
                            quickActionsGrid
                        } else {
                            ForEach(messages) { message in
                                messageBubble(message)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .scrollContentBackground(.hidden)

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
            }
        }
    }

    // MARK: - Context Banner

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

    // MARK: - Quick Actions

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
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
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
                        .background(AppColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(AppFont.caption2)
                        .foregroundColor(AppColors.disabledText)
                }
                .frame(maxWidth: .infinity * 0.78, alignment: .trailing)
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
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(AppFont.caption2)
                        .foregroundColor(AppColors.disabledText)
                }
                .frame(maxWidth: .infinity * 0.78, alignment: .leading)
                Spacer()
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask about this page…", text: $inputText)
                .font(AppFont.body)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                )
                .disabled(isGenerating)
                .onSubmit { sendQuestion() }

            Button {
                sendQuestion()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                     ? AppColors.disabledText : AppColors.accent)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(AppColors.surface.opacity(0.95))
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Actions

    private func runQuickAction(_ action: AIAction) {
        guard !isGenerating else { return }
        guard AISettings.shared.hasActiveProvider else {
            append(.assistant("Please configure and activate an AI provider in Settings → Lab Assistant to use this feature."))
            return
        }
        let userMessage = AIMessage.user("\(action.displayName) this page")
        append(userMessage)
        isGenerating = true

        Task {
            do {
                let context = TabContext(sourceView: sourceView, action: action, summary: summary)
                let stream = try await AIService.shared.respond(to: action, context: context)
                try await consume(stream)
            } catch {
                await fail(with: error)
            }
        }
    }

    private func sendQuestion() {
        let question = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isGenerating else { return }
        guard AISettings.shared.hasActiveProvider else {
            append(.assistant("Please configure and activate an AI provider in Settings → Lab Assistant to use this feature."))
            return
        }
        inputText = ""
        append(.user(question))
        isGenerating = true

        Task {
            do {
                let context = TabContext(sourceView: sourceView, action: .custom, summary: summary)
                let stream = try await AIService.shared.respond(
                    to: .custom,
                    context: context,
                    userQuestion: question
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
        await MainActor.run {
            append(.assistant(fullResponse))
            isGenerating = false
        }
    }

    private func fail(with error: Error) async {
        await MainActor.run {
            append(.assistant("Error: \(error.localizedDescription)"))
            isGenerating = false
        }
    }

    private func append(_ message: AIMessage) {
        withAnimation(.easeOut(duration: 0.2)) {
            messages.append(message)
        }
    }
}

// MARK: - Action Presentation Helpers

extension AIAction {
    var icon: String {
        switch self {
        case .explain:   return "questionmark.circle"
        case .analyze:   return "magnifyingglass"
        case .suggest:   return "lightbulb"
        case .summarize: return "text.alignleft"
        case .findIssues: return "exclamationmark.triangle"
        case .custom:    return "brain"
        }
    }

    var promptHint: String {
        switch self {
        case .explain:   return "Explain what's on this page and how it works"
        case .analyze:   return "Analyze the items here for problems or insights"
        case .suggest:   return "Suggest improvements or next steps"
        case .summarize: return "Give me a quick summary of this page"
        case .findIssues: return "Look for issues, warnings, or missing config"
        case .custom:    return "Ask a custom question"
        }
    }
}

#Preview {
    TabAssistantButton(sourceView: "Library", summary: "5 imported apps, 2 signed, 3 certificates")
}
