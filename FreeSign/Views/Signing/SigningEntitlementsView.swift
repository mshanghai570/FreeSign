import SwiftUI
import UniformTypeIdentifiers

// MARK: - Signing Entitlements View

/// View for selecting and managing a custom entitlements file for signing.
/// Mirrors Feather's SigningEntitlementsView, adapted for FreeSigniOS's card-based UI.
struct SigningEntitlementsView: View {
    @State private var isAddingPresenting = false
    @Binding var bindingValue: URL?

    var body: some View {
        List {
            Section {
                if let ent = bindingValue {
                    Label(ent.lastPathComponent, systemImage: "doc.text")
                        .font(AppFont.body)
                        .foregroundColor(AppColors.primaryText)
                        .swipeActions {
                            Button(role: .destructive) {
                                bindingValue = nil
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                } else {
                    Button {
                        isAddingPresenting = true
                    } label: {
                        Label("Select Entitlements File", systemImage: "doc.text.badge.plus")
                            .font(AppFont.body)
                            .foregroundColor(AppColors.accent)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            } header: {
                Text("Entitlements")
                    .appSectionHeader()
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .listRowBackground(AppColors.surface)
        .navigationTitle("Entitlements")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $isAddingPresenting,
            allowedContentTypes: [
                UTType.xmlPropertyList,
                UTType.binaryPropertyList,
                UTType("com.apple.security-application-entitlements")
            ].compactMap { $0 },
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            let code = (error as NSError).code
            if code != NSUserCancelledError && code != -1 {
                print("Entitlements import error: \(error.localizedDescription)")
            }
        case .success(let urls):
            guard let selectedFileURL = urls.first else { return }

            let accessed = selectedFileURL.startAccessingSecurityScopedResource()
            defer { if accessed { selectedFileURL.stopAccessingSecurityScopedResource() } }

            let tempDir = FileManager.default.temporaryDirectory
            let destURL = tempDir.appendingPathComponent(selectedFileURL.lastPathComponent)

            if FileManager.default.fileExists(atPath: destURL.path) {
                try? FileManager.default.removeItem(at: destURL)
            }

            do {
                try FileManager.default.copyItem(at: selectedFileURL, to: destURL)
                bindingValue = destURL
            } catch {
                print("Failed to copy entitlements file: \(error)")
            }
        }
    }
}

#Preview {
    NavigationStack {
        SigningEntitlementsView(bindingValue: .constant(nil))
    }
}
