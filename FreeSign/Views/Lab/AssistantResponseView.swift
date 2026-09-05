import SwiftUI

struct AssistantResponseView: View {
    let response: String
    let contextSummary: String
    let onContinueInNotebook: () -> Void
    let onDismiss: () -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(contextSummary)
                        .font(AppFont.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .padding(.horizontal, 4)

                    Text(response)
                        .font(AppFont.body)
                        .foregroundColor(AppColors.primaryText)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("Lab Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                    .foregroundColor(AppColors.secondaryText)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Continue in Notebook") {
                        onContinueInNotebook()
                        dismiss()
                    }
                    .foregroundColor(AppColors.accent)
                }
            }
        }
    }
}
