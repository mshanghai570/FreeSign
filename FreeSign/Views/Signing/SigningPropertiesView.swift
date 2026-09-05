import SwiftUI

// MARK: - Signing Properties View

/// A clean property editor for overriding the app's name, bundle ID, and version.
/// Mirrors Feather's SigningPropertiesView, adapted for FreeSigniOS's card-based UI.
struct SigningPropertiesView: View {
    @Environment(\.dismiss) var dismiss

    @State private var text: String = ""

    var title: String
    var initialValue: String
    @Binding var bindingValue: String?

    var saveButtonDisabled: Bool {
        text == initialValue
    }

    var body: some View {
        Form {
            Section {
                TextField(initialValue, text: $text)
                    .textInputAutocapitalization(.none)
                    .autocorrectionDisabled()
                    .foregroundColor(AppColors.primaryText)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .listRowBackground(AppColors.surface)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundColor(AppColors.secondaryText)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if !saveButtonDisabled {
                        bindingValue = text
                        dismiss()
                    }
                }
                .foregroundColor(AppColors.accent)
                .disabled(saveButtonDisabled)
            }
        }
        .onAppear {
            text = initialValue
        }
    }
}

#Preview {
    NavigationStack {
        SigningPropertiesView(
            title: "Display Name",
            initialValue: "Test App",
            bindingValue: .constant(nil)
        )
    }
}
