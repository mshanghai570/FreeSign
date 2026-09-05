import SwiftUI

// MARK: - Configuration Dict View

/// A key-value dictionary editor, mirroring Feather's ConfigurationDictView.
/// Used for managing Display Names and Identifiers replacement rules.
struct ConfigurationDictView: View {
    @State private var isAddingPresenting = false

    var title: String
    @Binding var dataDict: [String: String]

    var body: some View {
        List {
            if !dataDict.isEmpty {
                ForEach(dataDict.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    Section {
                        Text(value)
                            .font(AppFont.body)
                            .foregroundColor(AppColors.primaryText)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    dataDict.removeValue(forKey: key)
                                    OptionsManager.shared.saveOptions()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    } header: {
                        Text(key)
                            .font(AppFont.caption)
                            .foregroundColor(AppColors.secondaryText)
                            .textCase(.uppercase)
                    }
                }
                .onDelete(perform: delete)
            } else {
                Text("No entries yet.")
                    .font(AppFont.body)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .listRowBackground(AppColors.surface)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAddingPresenting = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .sheet(isPresented: $isAddingPresenting) {
            NavigationStack {
                ConfigurationDictAddView(dataDict: $dataDict)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        let sorted = dataDict.sorted(by: { $0.key < $1.key })
        for index in offsets {
            dataDict.removeValue(forKey: sorted[index].key)
        }
        OptionsManager.shared.saveOptions()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ConfigurationDictView(title: "Identifiers", dataDict: .constant(["com.example": "com.replaced"]))
    }
}
