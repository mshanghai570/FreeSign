import SwiftUI
import UIKit
import UniformTypeIdentifiers
import QuickLook
import Combine

// MARK: - FilesView

struct FilesView: View {
    @StateObject private var viewModel = FilesViewModel()
    @StateObject private var theme = ThemeManager.shared
    @State private var plistFileURL: URL?
    @State private var hexEditorFileURL: URL?
    @State private var textEditorFileURL: URL?
    @State private var quickLookFileURL: URL?
    @State private var localModelInfoFileURL: URL?
    @State private var moveFileItem: FileItem?
    @State private var navigateToDirectory: URL?
    @State private var showExtractProgress = false
    @State private var extractProgress = 0.0
    @State private var extractFileName = ""
    @State private var showNewFolderDialog = false
    @State private var showNewTextFileDialog = false
    @State private var newFolderName = ""
    @State private var newTextFileName = "Untitled.txt"
    @State private var selectedFileForAction: FileItem?
    @State private var showingActionSheet = false
    
    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle(viewModel.currentDirectory.lastPathComponent == "Documents" ? "Files" : viewModel.currentDirectory.lastPathComponent)
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search files...")
                .toolbar { toolbarContent }
                .modifier(fileModifiers)
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ZStack {
            theme.backgroundView
            
            VStack(spacing: 0) {
                // Workspace header
                workspaceHeader
                
                Divider()
                    .background(AppColors.cardBorder)
                
                // Category Filter Chips
                if !viewModel.files.isEmpty {
                    FileUIHelpers.categoryFilterChips(
                        selectedCategory: $viewModel.filterCategory,
                        fileCounts: fileCountsByCategory()
                    )
                }
                
                // File List
                filesContentView
            }
        }
    }
    
    // MARK: - Workspace Header
    
    private var workspaceHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.accentColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "folder")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(theme.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.currentDirectory.lastPathComponent == "Documents" ? "Workspace" : viewModel.currentDirectory.lastPathComponent)
                    .font(AppFont.headline)
                    .foregroundColor(AppColors.primaryText)
                Text("\(viewModel.files.count) item\(viewModel.files.count == 1 ? "" : "s")")
                    .font(AppFont.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - File Modifiers
    
    private var fileModifiers: some ViewModifier {
        FilesViewModifiers(
            viewModel: viewModel,
            plistFileURL: $plistFileURL,
            hexEditorFileURL: $hexEditorFileURL,
            textEditorFileURL: $textEditorFileURL,
            quickLookFileURL: $quickLookFileURL,
            localModelInfoFileURL: $localModelInfoFileURL,
            navigateToDirectory: $navigateToDirectory,
            showExtractProgress: $showExtractProgress,
            extractProgress: $extractProgress,
            extractFileName: $extractFileName,
            showNewFolderDialog: $showNewFolderDialog,
            showNewTextFileDialog: $showNewTextFileDialog,
            newFolderName: $newFolderName,
            newTextFileName: $newTextFileName,
            onFilePickerResult: handleFilePickerResult,
            onMoveResult: handleMoveResult,
            onNavigate: { url in
                navigateToDirectory = nil
                viewModel.currentDirectory = url
                viewModel.loadFiles()
            }
        )
    }
    
    // MARK: - Toolbar Content
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            // Sort menu
            Menu {
                ForEach(FilesViewModel.SortOption.allCases) { option in
                    Button {
                        if viewModel.sortOption == option {
                            viewModel.updateSort(option: option, ascending: !viewModel.sortAscending)
                        } else {
                            viewModel.updateSort(option: option, ascending: true)
                        }
                    } label: {
                        HStack {
                            Image(systemName: option.systemImage)
                            Text(option.displayName)
                            if viewModel.sortOption == option {
                                Image(systemName: viewModel.sortAscending ? "chevron.up" : "chevron.down")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(theme.accentColor)
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            // Add button
            Menu {
                Button {
                    viewModel.showingImporter = true
                } label: {
                    Label("Import Files", systemImage: "doc.badge.plus")
                }
                
                Button {
                    showNewFolderDialog = true
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                
                Button {
                    showNewTextFileDialog = true
                } label: {
                    Label("New Text File", systemImage: "doc.badge.plus")
                }
                
                Divider()
                
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        viewModel.isEditMode = viewModel.isEditMode == .active ? .inactive : .active
                        if viewModel.isEditMode == .inactive {
                            viewModel.selectedItems.removeAll()
                        }
                    }
                } label: {
                    Label(
                        viewModel.isEditMode == .active ? "Done" : "Select",
                        systemImage: viewModel.isEditMode == .active ? "checkmark.circle" : "checkmark.circle.badge.questionmark"
                    )
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.accentColor)
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .menuIndicator(.hidden)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            TabAssistantButton(sourceView: "Files", summary: filesAssistantSummary)
        }
        
        // Edit mode toolbar
        if viewModel.isEditMode == .active {
            ToolbarItem(placement: .bottomBar) {
                HStack(spacing: 16) {
                    // Select All
                    Button {
                        viewModel.selectAll()
                    } label: {
                        Label(
                            viewModel.isAllSelected ? "Deselect All" : "Select All",
                            systemImage: viewModel.isAllSelected ? "checklist.unchecked" : "checklist.checked"
                        )
                    }
                    .disabled(viewModel.filteredFiles.isEmpty)
                    
                    // Move
                    Button {
                        viewModel.showDirectoryPicker = true
                    } label: {
                        Label("Move", systemImage: "folder")
                    }
                    .disabled(viewModel.selectedItems.isEmpty)
                    
                    // Share
                    Button {
                        shareSelectedFiles()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .disabled(viewModel.selectedItems.isEmpty)
                    
                    // Delete
                    Button(role: .destructive) {
                        viewModel.deleteSelectedItems()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(viewModel.selectedItems.isEmpty)
                }
                .foregroundColor(theme.accentColor)
            }
        }
    }

    // MARK: - Assistant

    /// Summary of what is currently on the Files tab, for the Lab Assistant.
    private var filesAssistantSummary: String {
        let total = viewModel.files.count
        let models = viewModel.files.filter { $0.isLocalModelFile }.count
        let ipas = viewModel.files.filter { $0.isIPA }.count
        let folder = viewModel.currentDirectory.lastPathComponent
        return "Files tab: viewing \"\(folder)\" with \(total) item(s) "
             + "(\(models) model file(s), \(ipas) IPA(s))."
    }
    
    // MARK: - File Counts by Category
    
    private func fileCountsByCategory() -> [FileCategory: Int] {
        var counts: [FileCategory: Int] = [:]
        for category in FileCategory.allCases {
            counts[category] = viewModel.files.filter { category.matches($0) }.count
        }
        return counts
    }
    
    // MARK: - Files Content View
    
    @ViewBuilder
    private var filesContentView: some View {
        if viewModel.filteredFiles.isEmpty {
            FileUIHelpers.emptyStateView(for: viewModel.filterCategory) {
                viewModel.showingImporter = true
            }
        } else {
            List {
                ForEach(viewModel.filteredFiles) { file in
                    FileRow(
                        file: file,
                        isSelected: viewModel.selectedItems.contains(file),
                        viewModel: viewModel,
                        plistFileURL: $plistFileURL,
                        hexEditorFileURL: $hexEditorFileURL,
                        textEditorFileURL: $textEditorFileURL,
                        quickLookFileURL: $quickLookFileURL,
                        localModelInfoFileURL: $localModelInfoFileURL,
                        moveFileItem: $moveFileItem,
                        navigateToDirectory: $navigateToDirectory,
                        showExtractProgress: $showExtractProgress,
                        extractProgress: $extractProgress,
                        extractFileName: $extractFileName,
                        onExtractArchive: { file in
                            extractArchive(file)
                        },
                        onPackageApp: { file in
                            packageAppAsIPA(file)
                        },
                        onImportIPA: { file in
                            importIPAToLibrary(file)
                        },
                        onOpenInEditor: { file in
                            // Open in appropriate editor
                            if file.isPlistFile || file.isEntitlementsFile {
                                plistFileURL = file.url
                            } else if file.isTextFile || file.isCodeFile {
                                textEditorFileURL = file.url
                            } else if file.isLocalModelFile {
                                // Model weights are opaque binaries — show info
                                // instead of a failed Quick Look preview.
                                localModelInfoFileURL = file.url
                            } else {
                                quickLookFileURL = file.url
                            }
                        }
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, $viewModel.isEditMode)
        }
    }
    
    // MARK: - Swipe Actions
    
    @ViewBuilder
    private func swipeActions(for file: FileItem) -> some View {
        Button(role: .destructive) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.deleteFile(file)
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
        
        Button {
            UIAlertController.showAlertWithTextBox(
                title: "Rename",
                message: "Enter a new name",
                textFieldPlaceholder: "File name",
                textFieldText: file.name,
                submit: "Rename",
                cancel: "Cancel",
                onSubmit: { name in
                    viewModel.renameFile(newName: name, item: file)
                }
            )
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        .tint(.blue)
    }
    
    // MARK: - File Picker Handling
    
    private func handleFilePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            let code = (error as NSError).code
            if code != NSUserCancelledError && code != -1 {
                print("File import failed: \(error.localizedDescription)")
            }
            
        case .success(let urls):
            viewModel.importFiles(urls: urls)
        }
    }
    
    private func handleMoveResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            viewModel.moveSelectedItems(to: url)
        case .failure(let error):
            let code = (error as NSError).code
            if code != NSUserCancelledError && code != -1 {
                print("Move failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Archive Operations
    
    private func extractArchive(_ file: FileItem) {
        extractFileName = file.name
        showExtractProgress = true
        extractProgress = 0.0
        
        viewModel.extractArchive(file, progressCallback: { progress in
            DispatchQueue.main.async {
                self.extractProgress = progress
            }
        }) { result in
            DispatchQueue.main.async {
                self.showExtractProgress = false
                self.extractProgress = 0.0
                
                switch result {
                case .success(let message):
                    viewModel.loadFiles()
                case .failure(let error):
                    print("Extraction failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func packageAppAsIPA(_ file: FileItem) {
        extractFileName = file.name
        showExtractProgress = true
        extractProgress = 0.0
        
        viewModel.packageAppAsIPA(file, progressCallback: { progress in
            DispatchQueue.main.async {
                self.extractProgress = progress
            }
        }) { result in
            DispatchQueue.main.async {
                self.showExtractProgress = false
                self.extractProgress = 0.0
                
                switch result {
                case .success(let ipaName):
                    viewModel.loadFiles()
                case .failure(let error):
                    print("Packaging failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func importIPAToLibrary(_ file: FileItem) {
        // Import IPA to library - this would integrate with the existing library system
        print("Importing IPA to library: \(file.name)")
        // This would use the existing AppDataManager to add the IPA
    }
    
    private func shareSelectedFiles() {
        let urls = Array(viewModel.selectedItems.map { $0.url })
        let activityVC = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Files View Modifiers

private struct FilesViewModifiers: ViewModifier {
    @ObservedObject var viewModel: FilesViewModel
    @Binding var plistFileURL: URL?
    @Binding var hexEditorFileURL: URL?
    @Binding var textEditorFileURL: URL?
    @Binding var quickLookFileURL: URL?
    @Binding var localModelInfoFileURL: URL?
    @Binding var navigateToDirectory: URL?
    @Binding var showExtractProgress: Bool
    @Binding var extractProgress: Double
    @Binding var extractFileName: String
    @Binding var showNewFolderDialog: Bool
    @Binding var showNewTextFileDialog: Bool
    @Binding var newFolderName: String
    @Binding var newTextFileName: String
    let onFilePickerResult: (Result<[URL], Error>) -> Void
    let onMoveResult: (Result<URL, Error>) -> Void
    let onNavigate: (URL) -> Void
    
    func body(content: Content) -> some View {
        content
            .fileImporter(
                isPresented: $viewModel.showingImporter,
                allowedContentTypes: [.item],
                allowsMultipleSelection: true
            ) { result in
                onFilePickerResult(result)
            }
            .fullScreenCover(isPresented: Binding(
                get: { plistFileURL != nil },
                set: { if !$0 { plistFileURL = nil } }
            )) {
                if let url = plistFileURL {
                    SimplePlistEditorView(fileURL: url)
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { hexEditorFileURL != nil },
                set: { if !$0 { hexEditorFileURL = nil } }
            )) {
                if let url = hexEditorFileURL {
                    HexEditorView(fileURL: url)
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { textEditorFileURL != nil },
                set: { if !$0 { textEditorFileURL = nil } }
            )) {
                if let url = textEditorFileURL {
                    TextEditorView(fileURL: url)
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { quickLookFileURL != nil },
                set: { if !$0 { quickLookFileURL = nil } }
            )) {
                if let url = quickLookFileURL {
                    QuickLookPreview(fileURL: url)
                }
            }
            .sheet(isPresented: Binding(
                get: { localModelInfoFileURL != nil },
                set: { if !$0 { localModelInfoFileURL = nil } }
            )) {
                if let url = localModelInfoFileURL {
                    LocalModelInfoView(fileURL: url)
                }
            }
            .overlay {
                if showExtractProgress {
                    ExtractionProgressView(
                        fileName: extractFileName,
                        progress: extractProgress,
                        onCancel: {
                            showExtractProgress = false
                        }
                    )
                }
            }
            .onChange(of: navigateToDirectory) { newURL in
                if let url = newURL {
                    onNavigate(url)
                }
            }
            .alert("New Folder", isPresented: $showNewFolderDialog) {
                TextField("Folder name", text: $newFolderName)
                Button("Create") {
                    viewModel.createNewFolder(name: newFolderName)
                    newFolderName = ""
                }
                .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Cancel", role: .cancel) { newFolderName = "" }
            } message: {
                Text("Enter a name for the new folder")
            }
            .alert("New Text File", isPresented: $showNewTextFileDialog) {
                TextField("File name", text: $newTextFileName)
                Button("Create") {
                    viewModel.createNewTextFile(name: newTextFileName)
                    newTextFileName = "Untitled.txt"
                }
                .disabled(newTextFileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Cancel", role: .cancel) { newTextFileName = "Untitled.txt" }
            } message: {
                Text("Enter a name for the new text file")
            }
    }
}

// MARK: - QuickLook Preview

struct QuickLookPreview: UIViewControllerRepresentable {
    let fileURL: URL
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(fileURL: fileURL)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let fileURL: URL
        
        init(fileURL: URL) {
            self.fileURL = fileURL
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return fileURL as QLPreviewItem
        }
    }
}