import SwiftUI
import UniformTypeIdentifiers

// MARK: - Drop View for File Import

/// A view that can receive dropped files and handle import
struct DropView<Content: View>: View {
    @ViewBuilder let content: Content
    @StateObject private var fileImporter = FileImporter.shared
    
    var body: some View {
        content
            .onDrop(of: FileImporter.importUTTypes, isTargeted: nil) { providers -> Bool in
                // Handle dropped files
                handleDrop(providers: providers)
                return true
            }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak fileImporter] (item, error) in
                    if let url = item as? URL {
                        Task { @MainActor in
                            _ = fileImporter?.handleFileURL(url)
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.data.identifier, options: nil) { (item, error) in
                    if let data = item as? Data {
                        print("Received raw data: \(data.count) bytes")
                    }
                }
            }
        }
    }
}

// MARK: - Drop View Modifier

extension View {
    /// Adds drop support for file import
    func withFileDrop() -> some View {
        DropView { self }
    }
}