import SwiftUI

struct LabNotebookView: View {
    @State private var conversations: [AIConversation] = []
    @State private var activeConversation: AIConversation?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if conversations.isEmpty {
                    emptyState
                } else {
                    ForEach(conversations) { conversation in
                        NavigationLink {
                            LabConversationView(conversation: binding(for: conversation))
                        } label: {
                            LabConversationRow(conversation: conversation)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollContentBackground(.hidden)
        .background(ThemeManager.shared.backgroundView)
        .appNavigationTitle("Lab Notebook")
        .appNavigationStyle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    startNewConversation()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ThemeManager.shared.accentColor)
                }
            }
        }
        .onAppear {
            loadConversations()
        }
        .sheet(item: $activeConversation) { conversation in
            LabConversationView(conversation: binding(for: conversation))
        }
    }

    private func binding(for conversation: AIConversation) -> Binding<AIConversation> {
        guard let index = conversations.firstIndex(where: { $0.id == conversation.id }) else {
            return .constant(conversation)
        }
        return $conversations[index]
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book")
                .font(.system(size: 40))
                .foregroundColor(AppColors.disabledText)
            Text("No conversations yet")
                .font(AppFont.body)
                .foregroundColor(AppColors.secondaryText)
            Text("Use the assistant from any editor or view to start a conversation.")
                .font(AppFont.small)
                .foregroundColor(AppColors.disabledText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func loadConversations() {
        conversations = AIService.shared.notebookConversations()
    }

    private func startNewConversation() {
        let id = UUID()
        let conversation = AIConversation(
            id: id,
            title: "New Conversation",
            sourceView: "LabNotebook:\(id.uuidString)"
        )
        conversations.insert(conversation, at: 0)
        activeConversation = conversation
    }
}

struct LabConversationRow: View {
    let conversation: AIConversation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(conversation.title)
                    .font(AppFont.body)
                    .foregroundColor(AppColors.primaryText)
                Spacer()
                Text(conversation.updatedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(AppFont.caption)
                    .foregroundColor(AppColors.disabledText)
            }

            if let firstMessage = conversation.messages.first(where: { $0.role == .user }) {
                Text(firstMessage.content)
                    .font(AppFont.small)
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                Text(conversation.sourceView)
                    .font(AppFont.caption2)
                    .foregroundColor(AppColors.disabledText)
                Text("•")
                    .font(AppFont.caption2)
                    .foregroundColor(AppColors.disabledText)
                Text("\(conversation.messages.count) messages")
                    .font(AppFont.caption2)
                    .foregroundColor(AppColors.disabledText)
            }
        }
        .padding(14)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
    }
}

struct LabConversationView: View {
    @Binding var conversation: AIConversation
    @Environment(\.dismiss) private var dismiss
    @State private var inputText = ""
    @State private var isGenerating = false
    @State private var currentResponse = ""
    @State private var requestTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(conversation.messages) { message in
                    messageBubble(message)
                }

                if isGenerating {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .tint(AppColors.accent)
                        Text("Assistant is thinking...")
                            .font(AppFont.small)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .appNavigationTitle(conversation.title)
        .appNavigationStyle()
        .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        requestTask?.cancel()
                        dismiss()
                }
                .foregroundColor(AppColors.secondaryText)
            }
        }
        .safeAreaInset(edge: .bottom) {
            inputBar
        }
        .onAppear {
            if conversation.messages.isEmpty {
                inputText = ""
            }
        }
        .onDisappear {
            requestTask?.cancel()
        }
    }

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
                .frame(maxWidth: .infinity * 0.75, alignment: .trailing)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.content)
                        .font(AppFont.body)
                        .foregroundColor(AppColors.primaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(AppColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(AppFont.caption2)
                        .foregroundColor(AppColors.disabledText)
                }
                .frame(maxWidth: .infinity * 0.75, alignment: .leading)
                Spacer()
            }
        }
        .padding(.horizontal, 4)
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask a follow-up...", text: $inputText)
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

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppColors.disabledText : AppColors.accent)
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

    private func sendMessage() {
        let question = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

        let userMessage = AIMessage.user(question)
        conversation.messages.append(userMessage)
        conversation.updatedAt = Date()
        conversation = AIService.shared.saveNotebookConversation(conversation)
        inputText = ""
        isGenerating = true
        currentResponse = ""

        requestTask?.cancel()
        requestTask = Task {
            do {
                let context = DiagnosticContext(
                    sourceView: conversation.sourceView,
                    action: .custom,
                    report: DiagnosticEngine.generateReport()
                )
                let stream = try await AIService.shared.respond(
                    to: .custom,
                    context: context,
                    userQuestion: question,
                    history: Array(conversation.messages.dropLast())
                )
                var fullResponse = ""
                for try await chunk in stream {
                    fullResponse += chunk
                }
                await MainActor.run {
                    let assistantMessage = AIMessage.assistant(fullResponse)
                    conversation.messages.append(assistantMessage)
                    conversation.updatedAt = Date()
                    conversation = AIService.shared.saveNotebookConversation(conversation)
                    isGenerating = false
                }
            } catch is CancellationError {
                await MainActor.run {
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    let errorMessage = AIMessage.assistant("Error: \(error.localizedDescription)")
                    conversation.messages.append(errorMessage)
                    conversation.updatedAt = Date()
                    conversation = AIService.shared.saveNotebookConversation(conversation)
                    isGenerating = false
                }
            }
        }
    }
}
