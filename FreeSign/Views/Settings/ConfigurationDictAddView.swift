import SwiftUI

// MARK: - Configuration Dict Add View

/// View for adding or editing a key-value pair in a ConfigurationDictView,
/// mirroring Feather's ConfigurationDictAddView.
struct ConfigurationDictAddView: View {
    @Environment(\.dismiss) var dismiss

    @State private var newKey = ""
    @State private var newValue = ""
    @State private var showOverrideAlert = false

    var saveButtonDisabled: Bool {
        newKey.isEmpty || newValue.isEmpty
    }

    @Binding var dataDict: [String: String]

    var body: some View {
        Form {
            Section("Key") {
                TextField("Enter the value to match (e.g. com.example.app)", text: $newKey)
                    .textInputAutocapitalization(.none)
                    .autocorrectionDisabled()
            }
            Section("Replacement") {
                TextField("Enter the replacement value", text: $newValue)
                    .textInputAutocapitalization(.none)
                    .autocorrectionDisabled()
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .listRowBackground(AppColors.surface)
        .navigationTitle("New Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundColor(AppColors.secondaryText)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .foregroundColor(AppColors.accent)
                .disabled(saveButtonDisabled)
            }
        }
        .alert("Override Existing", isPresented: $showOverrideAlert) {
            Button("Replace", role: .destructive) {
                dataDict[newKey] = newValue
                OptionsManager.shared.saveOptions()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("An entry with this key already exists. Do you want to replace it?")
        }
    }

    private func save() {
        if dataDict[newKey] != nil {
            showOverrideAlert = true
        } else {
            dataDict[newKey] = newValue
            OptionsManager.shared.saveOptions()
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        ConfigurationDictAddView(dataDict: .constant([:]))
    }
}
