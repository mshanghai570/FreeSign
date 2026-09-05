import SwiftUI
import Foundation
import Combine

// MARK: - FilesViewModel

class FilesViewModel: ObservableObject {
    @Published var files: [FileItem] = []
    @Published var currentDirectory: URL
    @Published var selectedItems: Set<FileItem> = []
    @Published var isEditMode: EditMode = .inactive
    @Published var showingImporter = false
    @Published var showDirectoryPicker = false
    @Published var searchText = ""
    @Published var sortOption: SortOption = .name
    @Published var sortAscending: Bool = true
    @Published var filterCategory: FileCategory = .all
    
    enum SortOption: String, CaseIterable, Identifiable {
        case name = "Name"
        case date = "Date"
        case size = "Size"
        case type = "Type"
        
        var id: String { rawValue }
        var displayName: String { rawValue }
        var systemImage: String {
            switch self {
            case .name: return "textformat.alt"
            case .date: return "calendar"
            case .size: return "arrow.up.arrow.down"
            case .type: return "doc"
            }
        }
    }
    
    private let fileManager = FileManager.default
    private var cancellables = Set<AnyCancellable>()
    
    init(directory: URL? = nil) {
        if let directory = directory {
            self.currentDirectory = directory
        } else if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            self.currentDirectory = documentsDirectory
        } else {
            self.currentDirectory = URL(fileURLWithPath: "")
        }
        
        loadFiles()
    }
    
    // MARK: - File Loading
    
    private let internalDirectories: Set<String> = ["IPAs", "Signed", "Certificates", "Models", "Icons", "Extracts"]

    func loadFiles() {
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: currentDirectory,
                includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            let mapped = contents.compactMap { url -> FileItem? in
                // Hide internal app directories from the Files tab
                if url.hasDirectoryPath,
                   let lastComponent = url.pathComponents.last,
                   internalDirectories.contains(lastComponent) {
                    return nil
                }
                
                do {
                    let resourceValues = try url.resourceValues(
                        forKeys: [.isDirectoryKey, .creationDateKey, .fileSizeKey, .contentModificationDateKey]
                    )
                    let isDirectory = resourceValues.isDirectory ?? false
                    let creationDate = resourceValues.creationDate ?? resourceValues.contentModificationDate
                    let size = Int64(resourceValues.fileSize ?? 0)
                    
                    return FileItem(
                        name: url.lastPathComponent,
                        url: url,
                        size: size,
                        creationDate: creationDate,
                        isDirectory: isDirectory
                    )
                } catch {
                    print("Error getting file attributes for \(url): \(error)")
                    return nil
                }
            }
            
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    self.files = self.applySortAndFilter(to: mapped)
                }
            }
        } catch {
            DispatchQueue.main.async {
                print("Error loading files: \(error)")
            }
        }
    }
    
    // MARK: - Sorting & Filtering
    
    var filteredFiles: [FileItem] {
        applySortAndFilter(to: files)
    }
    
    private func applySortAndFilter(to files: [FileItem]) -> [FileItem] {
        var result = files.filter { filterCategory.matches($0) }
        
        if !searchText.isEmpty {
            result = result.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) 
            }
        }
        
        return result.sorted { a, b in
            let ascending = sortAscending
            
            switch sortOption {
            case .name:
                let cmp = a.name.localizedCaseInsensitiveCompare(b.name)
                return ascending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
            case .date:
                let ad = a.creationDate ?? .distantPast
                let bd = b.creationDate ?? .distantPast
                if ad == bd {
                    let cmp = a.name.localizedCaseInsensitiveCompare(b.name)
                    return ascending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
                }
                return ascending ? (ad < bd) : (ad > bd)
            case .size:
                if a.size == b.size {
                    let cmp = a.name.localizedCaseInsensitiveCompare(b.name)
                    return ascending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
                }
                return ascending ? (a.size < b.size) : (a.size > b.size)
            case .type:
                let at = fileTypeSortKey(for: a)
                let bt = fileTypeSortKey(for: b)
                let cmpType = at.localizedCaseInsensitiveCompare(bt)
                if cmpType == .orderedSame {
                    let cmpName = a.name.localizedCaseInsensitiveCompare(b.name)
                    return ascending ? (cmpName == .orderedAscending) : (cmpName == .orderedDescending)
                }
                return ascending ? (cmpType == .orderedAscending) : (cmpType == .orderedDescending)
            }
        }
    }
    
    private func fileTypeSortKey(for file: FileItem) -> String {
        if file.isDirectory {
            if file.isAppDirectory { return "00_AppBundle" }
            if file.isFrameworkDirectory { return "01_Framework" }
            return "02_Folder"
        }
        if file.isIPA { return "10_IPA" }
        if file.isArchive { return "11_Archive" }
        if file.isP12Certificate { return "20_Certificate" }
        if file.isMobileProvision { return "21_Profile" }
        if file.isPlistFile || file.isEntitlementsFile { return "30_Plist" }
        if file.isDylibFile { return "40_Dylib" }
        if file.isFrameworkDirectory { return "41_Framework" }
        if file.isImageFile { return "50_Image" }
        if file.isCodeFile { return "60_Code" }
        if file.isTextFile { return "61_Text" }
        return "99_Other"
    }
    
    func updateSort(option: SortOption, ascending: Bool) {
        sortOption = option
        sortAscending = ascending
    }
    
    func updateFilter(category: FileCategory) {
        filterCategory = category
    }
    
    // MARK: - File Operations
    
    func deleteFile(_ fileItem: FileItem) {
        delete(items: [fileItem])
    }
    
    func deleteSelectedItems() {
        guard !selectedItems.isEmpty else { return }
        let itemsToDelete = Array(selectedItems)
        delete(items: itemsToDelete)
        selectedItems.removeAll()
        if isEditMode == .active { isEditMode = .inactive }
    }
    
    private func delete(items: [FileItem]) {
        guard !items.isEmpty else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            var errorMessages: [String] = []
            
            for item in items {
                do {
                    try self.fileManager.removeItem(at: item.url)
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if let index = self.files.firstIndex(where: { $0.url == item.url }) {
                                self.files.remove(at: index)
                            }
                        }
                    }
                } catch {
                    errorMessages.append(item.name)
                    print("Error deleting \(item.name): \(error)")
                }
            }
            
            DispatchQueue.main.async {
                if !errorMessages.isEmpty {
                    print("Failed to delete \(errorMessages.count) items")
                }
            }
        }
    }
    
    func createNewFolder(name: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let sanitizedName = sanitizeFileName(name)
        let newFolderURL = currentDirectory.appendingPathComponent(sanitizedName)
        
        do {
            try fileManager.createDirectory(at: newFolderURL, withIntermediateDirectories: true, attributes: nil)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                loadFiles()
            }
        } catch {
            print("Error creating folder: \(error)")
        }
    }
    
    func createNewTextFile(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let sanitizedName = sanitizeFileName(trimmed)
        let newURL = currentDirectory.appendingPathComponent(sanitizedName)
        let finalURL = generateUniqueFileName(for: newURL)
        
        do {
            try Data().write(to: finalURL)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                loadFiles()
            }
        } catch {
            print("Error creating text file: \(error)")
        }
    }
    
    func renameFile(newName: String, item: FileItem) {
        guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let sanitizedName = sanitizeFileName(newName)
        let newURL = currentDirectory.appendingPathComponent(sanitizedName)
        
        do {
            try fileManager.moveItem(at: item.url, to: newURL)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                loadFiles()
            }
        } catch {
            print("Error renaming file: \(error)")
        }
    }
    
    func importFiles(urls: [URL]) {
        guard !urls.isEmpty else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            var failureCount = 0
            
            for url in urls {
                do {
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    
                    guard self.fileManager.fileExists(atPath: url.path) else {
                        throw NSError(domain: "FileImportError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Source file not accessible: \(url.lastPathComponent)"])
                    }
                    
                    let destinationURL = self.currentDirectory.appendingPathComponent(url.lastPathComponent)
                    let finalDestinationURL = self.generateUniqueFileName(for: destinationURL)
                    
                    try self.importSingleItem(from: url, to: finalDestinationURL)
                } catch {
                    failureCount += 1
                    print("Failed to import \(url.lastPathComponent): \(error)")
                }
            }
            
            DispatchQueue.main.async {
                if failureCount > 0 {
                    print("Failed to import \(failureCount) file(s)")
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    self.loadFiles()
                }
            }
        }
    }
    
    private func importSingleItem(from sourceURL: URL, to destinationURL: URL) throws {
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw NSError(
                domain: "FileImportError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Source does not exist: \(sourceURL.path)"]
            )
        }
        
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory)
        
        if isDirectory.boolValue {
            try copyDirectory(from: sourceURL, to: destinationURL)
        } else {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        }
    }
    
    private func copyDirectory(from sourceURL: URL, to destinationURL: URL) throws {
        let contents = try fileManager.contentsOfDirectory(atPath: sourceURL.path)
        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        
        for item in contents {
            let sourceItem = sourceURL.appendingPathComponent(item)
            let destItem = destinationURL.appendingPathComponent(item)
            var isDir: ObjCBool = false
            fileManager.fileExists(atPath: sourceItem.path, isDirectory: &isDir)
            
            if isDir.boolValue {
                try copyDirectory(from: sourceItem, to: destItem)
            } else {
                try fileManager.copyItem(at: sourceItem, to: destItem)
            }
        }
    }
    
    private func generateUniqueFileName(for url: URL) -> URL {
        if !fileManager.fileExists(atPath: url.path) {
            return url
        }
        
        let directory = url.deletingLastPathComponent()
        let filename = url.deletingPathExtension().lastPathComponent
        let pathExtension = url.pathExtension
        
        var counter = 1
        var newURL: URL
        
        repeat {
            let newFilename = pathExtension.isEmpty 
                ? "\(filename) (\(counter))"
                : "\(filename) (\(counter)).\(pathExtension)"
            newURL = directory.appendingPathComponent(newFilename)
            counter += 1
        } while fileManager.fileExists(atPath: newURL.path) && counter < 1000
        
        return newURL
    }
    
    func moveSelectedItems(to destinationURL: URL) {
        guard !selectedItems.isEmpty else { return }
        
        let itemsToMove = Array(selectedItems)
        
        DispatchQueue.global(qos: .userInitiated).async {
            for item in itemsToMove {
                let destURL = destinationURL.appendingPathComponent(item.name)
                let finalDestURL = self.generateUniqueFileName(for: destURL)
                
                do {
                    try self.fileManager.moveItem(at: item.url, to: finalDestURL)
                } catch {
                    print("Error moving \(item.name): \(error)")
                }
            }
            
            DispatchQueue.main.async {
                self.selectedItems.removeAll()
                if self.isEditMode == .active { self.isEditMode = .inactive }
                self.loadFiles()
            }
        }
    }
    
    private func sanitizeFileName(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:?*<>|\"\\")
        return name.components(separatedBy: invalidCharacters).joined()
    }
    
    // MARK: - Archive Operations
    
    func extractArchive(_ file: FileItem, progressCallback: @escaping (Double) -> Void, completion: @escaping (Result<String, Error>) -> Void) {
        guard file.isArchive else { 
            completion(.failure(NSError(domain: "ExtractError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not an archive"])))
            return 
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.performExtraction(file: file, to: self.currentDirectory, progressCallback: progressCallback, completion: completion)
        }
    }
    
    private func performExtraction(file: FileItem, to destination: URL, progressCallback: @escaping (Double) -> Void, completion: @escaping (Result<String, Error>) -> Void) {
        // Use ZSignWrapper's built-in zip extraction (iOS-compatible)
        progressCallback(0.1)
        
        do {
            let extractPath = try ZSignWrapper.extractIPA(atPath: file.url.path)
            
            progressCallback(0.6)
            
            // Move extracted contents to the destination directory
            let extractURL = URL(fileURLWithPath: extractPath)
            let contents = try FileManager.default.contentsOfDirectory(at: extractURL, includingPropertiesForKeys: nil)
            for item in contents {
                let destURL = destination.appendingPathComponent(item.lastPathComponent)
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.moveItem(at: item, to: destURL)
            }
            try FileManager.default.removeItem(at: extractURL)
        } catch {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
            return
        }
        
        progressCallback(1.0)
        DispatchQueue.main.async {
            completion(.success("Extracted successfully"))
        }
    }
    
    func packageAppAsIPA(_ file: FileItem, progressCallback: @escaping (Double) -> Void, completion: @escaping (Result<String, Error>) -> Void) {
        guard file.isAppDirectory else { 
            completion(.failure(NSError(domain: "PackageError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not an app bundle"])))
            return 
        }
        
        // Use ZSignWrapper's built-in zip archiving (iOS-compatible)
        DispatchQueue.global(qos: .userInitiated).async {
            let ipaName = file.name.replacingOccurrences(of: ".app", with: "") + ".ipa"
            let ipaURL = self.currentDirectory.appendingPathComponent(ipaName)
            let finalIPAURL = self.generateUniqueFileName(for: ipaURL)
            
            // Create a temp folder with Payload/ structure
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("freesign_pkg_\(UUID().uuidString)")
            let payloadDir = tempDir.appendingPathComponent("Payload")
            
            do {
                try FileManager.default.createDirectory(at: payloadDir, withIntermediateDirectories: true)
                let appDest = payloadDir.appendingPathComponent(file.name)
                try FileManager.default.copyItem(at: file.url, to: appDest)
                
                try ZSignWrapper.archivePayloadFolder(tempDir.path, toIPAAtPath: finalIPAURL.path)
                
                try FileManager.default.removeItem(at: tempDir)
                
                DispatchQueue.main.async {
                    self.loadFiles()
                    completion(.success(ipaName))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Selection Helpers
    
    func toggleSelection(for file: FileItem) {
        if selectedItems.contains(file) {
            selectedItems.remove(file)
        } else {
            selectedItems.insert(file)
        }
    }
    
    func selectAll() {
        if selectedItems.count == filteredFiles.count {
            selectedItems.removeAll()
        } else {
            selectedItems = Set(filteredFiles)
        }
    }
    
    var isAllSelected: Bool {
        !filteredFiles.isEmpty && selectedItems.count == filteredFiles.count
    }
}