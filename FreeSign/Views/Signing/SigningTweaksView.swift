import SwiftUI
import UniformTypeIdentifiers

// MARK: - Signing Tweaks View

/// View for managing injection files (.dylib, .deb) to be applied during signing.
/// Mirrors Feather's SigningTweaksView, adapted for FreeSigniOS's card-based UI.
struct SigningTweaksView: View {
    @StateObject private var optionsManager = OptionsManager.shared
    @State private var isAddingPresenting = false

    @Binding var options: Options

    var body: some View {
        List {
            injectionSection
            tweaksSection
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .listRowBackground(AppColors.surface)
        .navigationTitle("Tweaks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                addButton
            }
        }
        .fileImporter(
            isPresented: $isAddingPresenting,
            allowedContentTypes: Self.tweakContentTypes,
            allowsMultipleSelection: true
        ) { result in
            handleImportResult(result)
        }
        .onChange(of: options) { _ in
            optionsManager.saveOptions()
        }
        .animation(.easeInOut(duration: 0.2), value: options.injectionFiles)
    }

    // MARK: - Sub-Expressions

    private var addButton: some View {
        Button {
            isAddingPresenting = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.accent)
        }
    }

    private var injectionSection: some View {
        Section {
            Picker(selection: $options.injectPath) {
                ForEach(Options.InjectPath.allCases, id: \.self) { path in
                    Text(path.rawValue).tag(path)
                }
            } label: {
                Label("Injection Path", systemImage: "doc.badge.gearshape")
            }

            Picker(selection: $options.injectFolder) {
                ForEach(Options.InjectFolder.allCases, id: \.self) { folder in
                    Text(folder.rawValue).tag(folder)
                }
            } label: {
                Label("Injection Folder", systemImage: "folder.badge.gearshape")
            }

            Toggle(isOn: $options.injectIntoExtensions) {
                Label("Inject into Extensions", systemImage: "syringe")
            }
            .tint(AppColors.accent)
        } header: {
            Text("Injection")
                .appSectionHeader()
        }
    }

    private var tweaksSection: some View {
        Section {
            if !options.injectionFiles.isEmpty {
                ForEach(options.injectionFiles, id: \.absoluteString) { tweak in
                    _file(tweak: tweak)
                }
            } else {
                Text("No files chosen.")
                    .font(AppFont.body)
                    .foregroundColor(AppColors.secondaryText)
            }
        } header: {
            Text("Tweaks")
                .appSectionHeader()
        }
    }

    private static let tweakContentTypes: [UTType] = [
        UTType(filenameExtension: "dylib"),
        UTType("com.apple.application-bundle"),
        UTType("org.cydia.deb"),
        .data
    ].compactMap { $0 }

    // MARK: - File Row

    @ViewBuilder
    private func _file(tweak: URL) -> some View {
        Label(tweak.lastPathComponent, systemImage: "folder.fill")
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(AppFont.body)
            .foregroundColor(AppColors.primaryText)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    if let index = options.injectionFiles.firstIndex(where: { $0 == tweak }) {
                        options.injectionFiles.remove(at: index)
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .contextMenu {
                Button(role: .destructive) {
                    if let index = options.injectionFiles.firstIndex(where: { $0 == tweak }) {
                        options.injectionFiles.remove(at: index)
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

    // MARK: - File Importer

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            let code = (error as NSError).code
            if code != NSUserCancelledError && code != -1 {
                print("Tweak import error: \(error.localizedDescription)")
            }
        case .success(let urls):
            for url in urls {
                copyAndStoreTweak(url)
            }
        }
    }

    private func copyAndStoreTweak(_ sourceURL: URL) {
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }

        let fileName = sourceURL.lastPathComponent
        let destURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Tweaks")
            .appendingPathComponent(fileName)

        try? FileManager.default.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: destURL.path) {
            try? FileManager.default.removeItem(at: destURL)
        }

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            if !options.injectionFiles.contains(destURL) {
                options.injectionFiles.append(destURL)
            }
        } catch {
            print("Failed to copy tweak: \(error.localizedDescription)")
        }
    }
}

#Preview {
    NavigationStack {
        SigningTweaksView(options: .constant(Options.defaultOptions))
    }
}
