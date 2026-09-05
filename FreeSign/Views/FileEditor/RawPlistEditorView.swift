import SwiftUI

struct RawPlistEditorView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var rawText: String
    let onSave: (String) -> Void
    @State private var editText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Editor header
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.accent)
                    Text("Raw XML Editor")
                        .font(AppFont.headline)
                        .foregroundColor(AppColors.primaryText)
                    Spacer()
                }
                .padding(16)
                .background(AppColors.surface)
                
                // Editor
                TextEditor(text: $editText)
                    .font(AppFont.mono)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(12)
                    .scrollContentBackground(.hidden)
                    .background(AppColors.background)
                    .foregroundColor(AppColors.primaryText)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )
                    .padding(16)
            }
            .background(AppColors.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(AppFont.body)
                        .foregroundColor(AppColors.secondaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        withAnimation(.easeOut(duration: 0.2)) {
                            onSave(editText)
                        }
                        dismiss()
                    }
                    .font(AppFont.button)
                    .foregroundColor(AppColors.accent)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                    .font(AppFont.body.bold())
                    .foregroundColor(AppColors.accent)
                }
            }
            .onAppear { editText = rawText }
        }
    }
}

#Preview {
    RawPlistEditorView(rawText: .constant("<?xml..."), onSave: { _ in })
}
