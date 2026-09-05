import Foundation
import UniformTypeIdentifiers

/// Provides file-system level editing capabilities for extracted IPA bundles.
/// Mirrors eSign's ability to browse and modify app bundles before signing.
class BundleEditor: ObservableObject {
    static let shared = BundleEditor()
    
    @Published var extractedApps: [ExtractedApp] = []
    
    struct ExtractedApp: Identifiable {
        let id = UUID()
        let sourceIPA: String
        let extractPath: String
        let appFolderPath: String
        let bundleID: String
        var appName: String
        var version: String
        var minOS: String
        var iconPath: String?
        
        var payloadPath: String {
            (extractPath as NSString).appendingPathComponent("Payload")
        }
    }
    
    /// Extract an IPA and discover its .app bundle
    func extractIPA(_ ipaPath: String) throws -> ExtractedApp {
        // Extract using Zsign's zip engine via Obj-C bridge
        // The Obj-C method auto-renames to extractIPA(atPath:) and throws on failure
        guard let extractPath = try? ZSignWrapper.extractIPA(atPath: ipaPath) else {
            throw BundleError.extractionFailed("Failed to extract IPA")
        }
        
        // Find the .app folder
        let payloadPath = (extractPath as NSString).appendingPathComponent("Payload")
        let contents = try FileManager.default.contentsOfDirectory(atPath: payloadPath)
        guard let appFolder = contents.first(where: { $0.hasSuffix(".app") }) else {
            throw BundleError.noAppBundleFound
        }
        let appFolderPath = (payloadPath as NSString).appendingPathComponent(appFolder)
        
        // Parse Info.plist
        let infoPlistPath = (appFolderPath as NSString).appendingPathComponent("Info.plist")
        guard let infoDict = NSDictionary(contentsOfFile: infoPlistPath) as? [String: Any] else {
            throw BundleError.invalidInfoPlist
        }
        
        let name = (infoDict["CFBundleDisplayName"] as? String) ??
                   (infoDict["CFBundleName"] as? String) ??
                   appFolder.replacingOccurrences(of: ".app", with: "")
        let bundleID = infoDict["CFBundleIdentifier"] as? String ?? "unknown"
        let version = infoDict["CFBundleShortVersionString"] as? String ?? "1.0"
        let minOS = infoDict["MinimumOSVersion"] as? String ?? "12.0"
        
        // Find icon
        let iconPath = findAppIcon(in: appFolderPath)
        
        let extracted = ExtractedApp(
            sourceIPA: ipaPath,
            extractPath: extractPath,
            appFolderPath: appFolderPath,
            bundleID: bundleID,
            appName: name,
            version: version,
            minOS: minOS,
            iconPath: iconPath
        )
        
        extractedApps.append(extracted)
        return extracted
    }
    
    /// Read a plist file as a dictionary
    func readPlist(at path: String) throws -> [String: Any] {
        guard let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            throw BundleError.invalidPlist
        }
        return dict
    }
    
    /// Write a plist dictionary to file
    func writePlist(_ dict: [String: Any], to path: String) throws {
        let nsDict = NSDictionary(dictionary: dict)
        guard nsDict.write(toFile: path, atomically: true) else {
            throw BundleError.writeFailed("Failed to write plist")
        }
    }
    
    /// Read file contents as Data
    func readFile(at path: String) throws -> Data {
        return try Data(contentsOf: URL(fileURLWithPath: path))
    }
    
    /// Write data to file
    func writeFile(_ data: Data, to path: String) throws {
        try data.write(to: URL(fileURLWithPath: path))
    }
    
    /// List files in a directory recursively (relative paths)
    func listFiles(in directory: String) throws -> [FileEntry] {
        var entries: [FileEntry] = []
        let enumerator = FileManager.default.enumerator(atPath: directory)
        while let path = enumerator?.nextObject() as? String {
            let fullPath = (directory as NSString).appendingPathComponent(path)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }
            
            // Skip hidden files
            let lastComp = (path as NSString).lastPathComponent
            if lastComp.hasPrefix(".") { continue }
            
            let attrs = try FileManager.default.attributesOfItem(atPath: fullPath)
            let fileSize = attrs[.size] as? Int64 ?? 0
            
            entries.append(FileEntry(
                relativePath: path,
                isDirectory: isDir.boolValue,
                fileSize: fileSize,
                modificationDate: attrs[.modificationDate] as? Date ?? Date()
            ))
        }
        return entries.sorted { $0.relativePath < $1.relativePath }
    }
    
    /// Replace an icon in the app bundle
    func replaceAppIcon(in appFolder: String, with imageData: Data) throws -> String {
        // Find the CFBundleIconFiles or CFBundleIcons entry
        let infoPath = (appFolder as NSString).appendingPathComponent("Info.plist")
        guard (try? readPlist(at: infoPath)) != nil else {
            throw BundleError.invalidInfoPlist
        }
        
        // Look for existing icon files to overwrite
        let iconFiles = try findIconFiles(in: appFolder)
        if let firstIcon = iconFiles.first {
            let iconPath = (appFolder as NSString).appendingPathComponent(firstIcon)
            try imageData.write(to: URL(fileURLWithPath: iconPath))
            return firstIcon
        }
        
        // If no existing icons found, create one
        let iconName = "AppIcon60x60@2x.png"
        let iconPath = (appFolder as NSString).appendingPathComponent(iconName)
        try imageData.write(to: URL(fileURLWithPath: iconPath))
        return iconName
    }
    
    /// Clean up extracted bundle
    func cleanup(_ extracted: ExtractedApp) {
        try? FileManager.default.removeItem(atPath: extracted.extractPath)
        extractedApps.removeAll { $0.id == extracted.id }
    }
    
    func cleanupAll() {
        for app in extractedApps {
            try? FileManager.default.removeItem(atPath: app.extractPath)
        }
        extractedApps.removeAll()
    }
    
    // MARK: - Private
    
    private func findAppIcon(in appFolder: String) -> String? {
        guard let iconFiles = try? findIconFiles(in: appFolder) else { return nil }
        guard let first = iconFiles.first else { return nil }
        return (appFolder as NSString).appendingPathComponent(first)
    }
    
    private func findIconFiles(in appFolder: String) throws -> [String] {
        let infoPath = (appFolder as NSString).appendingPathComponent("Info.plist")
        guard let info = NSDictionary(contentsOfFile: infoPath) as? [String: Any] else {
            return []
        }
        
        var iconNames: [String] = []
        
        // iOS 5+ CFBundleIcons
        if let bundleIcons = info["CFBundleIcons"] as? [String: Any] {
            if let primary = bundleIcons["CFBundlePrimaryIcon"] as? [String: Any] {
                if let files = primary["CFBundleIconFiles"] as? [String] {
                    iconNames.append(contentsOf: files)
                }
                if let files = primary["CFBundleIconName"] as? String {
                    iconNames.append(files)
                }
            }
        }
        
        // iOS 5+ CFBundleIcons~ipad
        if let bundleIcons = info["CFBundleIcons~ipad"] as? [String: Any] {
            if let primary = bundleIcons["CFBundlePrimaryIcon"] as? [String: Any] {
                if let files = primary["CFBundleIconFiles"] as? [String] {
                    iconNames.append(contentsOf: files)
                }
            }
        }
        
        // Legacy CFBundleIconFile
        if let legacyIcon = info["CFBundleIconFile"] as? String {
            iconNames.append(legacyIcon)
        }
        
        // Resolve to actual files in the bundle
        var resolved = iconNames.compactMap { name -> String? in
            // Try exact name, then @2x, then @3x variants
            let variants = [
                name,
                "\(name)@2x",
                "\(name)@3x",
                "\(name).png",
                "\(name)@2x.png",
                "\(name)@3x.png"
            ]
            for variant in variants {
                let path = (appFolder as NSString).appendingPathComponent(variant)
                if FileManager.default.fileExists(atPath: path) {
                    return variant
                }
            }
            return nil
        }
        
        // Fallback: scan for PNG files
        if resolved.isEmpty {
            let enumerator = FileManager.default.enumerator(atPath: appFolder)
            while let file = enumerator?.nextObject() as? String {
                if file.hasSuffix(".png") && file.contains("Icon") {
                    resolved.append(file)
                }
            }
        }
        
        return resolved
    }
}

struct FileEntry: Identifiable {
    let id = UUID()
    let relativePath: String
    let isDirectory: Bool
    let fileSize: Int64
    let modificationDate: Date
    
    var fileName: String { (relativePath as NSString).lastPathComponent }
    var fileExtension: String { (fileName as NSString).pathExtension.lowercased() }
    var isPlist: Bool { fileExtension == "plist" }
    var isImage: Bool { ["png", "jpg", "jpeg", "gif", "webp"].contains(fileExtension) }
    var isTextEditable: Bool { ["plist", "xml", "json", "strings", "entitlements", "cfg", "conf"].contains(fileExtension) }
}

enum BundleError: LocalizedError {
    case extractionFailed(String)
    case noAppBundleFound
    case invalidInfoPlist
    case invalidPlist
    case writeFailed(String)
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .extractionFailed(let msg): return "Extraction failed: \(msg)"
        case .noAppBundleFound: return "No .app bundle found in Payload"
        case .invalidInfoPlist: return "Invalid or missing Info.plist"
        case .invalidPlist: return "Invalid plist format"
        case .writeFailed(let msg): return "Write failed: \(msg)"
        case .fileNotFound: return "File not found"
        }
    }
}

// MARK: - Obj-C Bridging (used by BundleEditor.extractIPA)
// The ZSignWrapper class is imported from the bridging header
