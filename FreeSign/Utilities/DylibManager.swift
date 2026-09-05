import Foundation
import UniformTypeIdentifiers

// MARK: - Dylib Manager

/// Manages dylib injection and analysis for IPA files
final class DylibManager: ObservableObject {
    
    static let shared = DylibManager()
    
    @Published var injectedDylibs: [InjectedDylib] = []
    @Published var availableDylibs: [DylibFile] = []
    
    private let dylibsDirectory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Dylibs", isDirectory: true)
    }()
    
    private init() {
        loadAvailableDylibs()
    }
    
    // MARK: - Dylib Analysis
    
    /// Analyze an IPA for existing dylibs
    /// - Parameter ipaPath: Path to the IPA file
    /// - Returns: Array of DylibInfo for existing dylibs
    func analyzeDylibs(in ipaPath: String) -> [DylibInfo] {
        // This would extract the IPA and scan for dylibs
        // For now, return placeholder data
        return []
    }
    
    /// Analyze an IPA for embedded frameworks
    /// - Parameter ipaPath: Path to the IPA file
    /// - Returns: Array of framework names
    func analyzeFrameworks(in ipaPath: String) -> [String] {
        // This would extract the IPA and scan for frameworks
        // For now, return the data from AppInfo if available
        return []
    }
    
    /// Analyze an IPA for plugins
    /// - Parameter ipaPath: Path to the IPA file
    /// - Returns: Array of plugin info
    func analyzePlugins(in ipaPath: String) -> [PluginInfo] {
        // This would extract the IPA and scan for plugins
        return []
    }
    
    // MARK: - Dylib Injection
    
    /// Inject a dylib into an IPA
    /// - Parameters:
    ///   - dylibPath: Path to the dylib file
    ///   - ipaPath: Path to the target IPA
    ///   - options: Injection options
    /// - Returns: Path to the modified IPA
    /// - Throws: DylibError on failure
    func injectDylib(_ dylibPath: String, into ipaPath: String, options: DylibInjectionOptions = .default) throws -> String {
        // This would use ZSign's injection capabilities
        // For now, implement basic logic
        
        // 1. Validate the dylib file
        guard FileManager.default.fileExists(atPath: dylibPath) else {
            throw DylibError.dylibNotFound
        }
        
        // 2. Validate the IPA file
        guard FileManager.default.fileExists(atPath: ipaPath) else {
            throw DylibError.ipaNotFound
        }
        
        // 3. Create output path
        let outputName = URL(fileURLWithPath: ipaPath).deletingPathExtension().lastPathComponent + "_injected.ipa"
        let outputURL = StorageManager.shared.ipasURL.appendingPathComponent(outputName)
        
        // 4. Copy the original IPA
        try FileManager.default.copyItem(atPath: ipaPath, toPath: outputURL.path)
        
        // 5. Inject the dylib (this would use ZSign's actual injection)
        // For now, just log the operation
        print("Injecting dylib: \(dylibPath) into IPA: \(ipaPath)")
        
        // 6. Record the injection
        let injectedDylib = InjectedDylib(
            id: UUID(),
            name: URL(fileURLWithPath: dylibPath).lastPathComponent,
            path: dylibPath,
            targetIPA: ipaPath,
            outputIPA: outputURL.path,
            dateInjected: Date(),
            options: options
        )
        
        injectedDylibs.append(injectedDylib)
        
        return outputURL.path
    }
    
    /// Remove an injected dylib from an IPA
    /// - Parameter injection: The injection to remove
    func removeInjectedDylib(_ injection: InjectedDylib) {
        // Remove the output IPA file
        try? FileManager.default.removeItem(atPath: injection.outputIPA)
        
        // Remove from the list
        injectedDylibs.removeAll { $0.id == injection.id }
    }
    
    // MARK: - Dylib Management
    
    /// Import a dylib file
    /// - Parameter url: URL of the dylib file
    /// - Returns: The imported DylibFile
    func importDylib(from url: URL) throws -> DylibFile {
        // Access security-scoped resource
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        
        // Validate file extension
        guard url.pathExtension.lowercased() == "dylib" else {
            throw DylibError.invalidFileType
        }
        
        // Create destination path
        let destURL = dylibsDirectory.appendingPathComponent(url.lastPathComponent)
        
        // Copy the file
        try FileManager.default.createDirectory(at: dylibsDirectory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: url, to: destURL)
        
        // Create DylibFile model
        let dylib = DylibFile(
            id: UUID(),
            name: url.deletingPathExtension().lastPathComponent,
            path: destURL.path,
            fileSize: try FileManager.default.attributesOfItem(atPath: destURL.path)[.size] as? Int64 ?? 0,
            dateAdded: Date()
        )
        
        availableDylibs.append(dylib)
        
        return dylib
    }
    
    /// Remove a dylib file
    /// - Parameter dylib: The dylib to remove
    func removeDylib(_ dylib: DylibFile) {
        // Remove the file
        try? FileManager.default.removeItem(atPath: dylib.path)
        
        // Remove from the list
        availableDylibs.removeAll { $0.id == dylib.id }
    }
    
    /// Load available dylibs from disk
    private func loadAvailableDylibs() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: dylibsDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        availableDylibs = files.compactMap { url in
            guard url.pathExtension.lowercased() == "dylib" else { return nil }
            
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes?[.size] as? Int64 ?? 0
            
            return DylibFile(
                id: UUID(),
                name: url.deletingPathExtension().lastPathComponent,
                path: url.path,
                fileSize: fileSize,
                dateAdded: Date() // Would need to store actual date
            )
        }
    }
}

// MARK: - Models

/// Information about a dylib in an IPA
struct DylibInfo: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let isInjected: Bool
    let architecture: String
}

/// Information about a framework in an IPA
struct FrameworkInfo: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let isEmbedded: Bool
}

/// Information about a plugin in an IPA
struct PluginInfo: Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let path: String
    let size: Int64
}

/// A dylib file available for injection
struct DylibFile: Identifiable, Codable {
    let id: UUID
    let name: String
    let path: String
    let fileSize: Int64
    let dateAdded: Date
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

/// Record of an injected dylib
struct InjectedDylib: Identifiable, Codable {
    let id: UUID
    let name: String
    let path: String
    let targetIPA: String
    let outputIPA: String
    let dateInjected: Date
    let options: DylibInjectionOptions
}

/// Options for dylib injection
struct DylibInjectionOptions: Codable {
    var overwriteExisting: Bool = false
    var backupOriginal: Bool = true
    var verifySignature: Bool = false
    
    static let `default` = DylibInjectionOptions()
}

// MARK: - Errors

enum DylibError: LocalizedError {
    case dylibNotFound
    case ipaNotFound
    case invalidFileType
    case injectionFailed
    case extractionFailed
    
    var errorDescription: String? {
        switch self {
        case .dylibNotFound: return "Dylib file not found."
        case .ipaNotFound: return "IPA file not found."
        case .invalidFileType: return "Invalid file type. Only .dylib files are supported."
        case .injectionFailed: return "Failed to inject dylib into IPA."
        case .extractionFailed: return "Failed to extract IPA for analysis."
        }
    }
}

// MARK: - Dylib Analysis Extension

extension IPAAnalyzer {
    /// Enhanced analyze method that includes dylib, framework, and plugin analysis
    func analyzeWithComponents(ipaPath: String) throws -> (Result, [DylibInfo], [FrameworkInfo], [PluginInfo]) {
        let result = try analyze(ipaPath: ipaPath)
        
        // For now, return placeholder data
        // In a real implementation, this would extract and analyze the IPA
        let dylibs: [DylibInfo] = []
        let frameworks: [FrameworkInfo] = result.embeddedFrameworks.map { name in
            FrameworkInfo(
                name: name,
                path: "Payload/" + result.name + ".app/Frameworks/" + name,
                size: 0,
                isEmbedded: true
            )
        }
        let plugins: [PluginInfo] = []
        
        return (result, dylibs, frameworks, plugins)
    }
}