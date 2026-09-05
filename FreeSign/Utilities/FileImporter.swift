import SwiftUI
import UniformTypeIdentifiers

// MARK: - File Importer Utility

/// Centralized file importing utility that handles various file types
/// and provides a consistent interface for importing files into FreeSign.
final class FileImporter: ObservableObject {
    
    static let shared = FileImporter()
    
    @Published var isImporting = false
    @Published var importProgress = ""
    @Published var currentFileURL: URL?
    /// Populated when an import fails (for UI feedback).
    @Published var lastImportError: String?

    /// "Open with" events fire BOTH the AppDelegate callback and SwiftUI's
    /// onOpenURL — dedupe so we don't import the same file twice.
    private var lastHandledURL: URL?
    private var lastHandledDate = Date.distantPast

    private init() {}
    
    // MARK: - Supported File Types
    
    /// Resolves a UTType without force-unwrapping — custom identifiers from Info.plist
    /// are not always available during static initialization on device.
    private static func resolvedUTTypes(
        identifiers: [String],
        filenameExtensions: [String] = []
    ) -> [UTType] {
        var types: [UTType] = []
        for id in identifiers {
            if let type = UTType(id) {
                types.append(type)
            }
        }
        for ext in filenameExtensions {
            if let type = UTType(filenameExtension: ext) {
                types.append(type)
            }
        }
        if types.isEmpty {
            types.append(.data)
        }
        return types.removingDuplicates()
    }
    
    /// All supported file types and their UTTypes
    static let supportedFileTypes: [FileType] = [
        FileType(
            name: "IPA Files",
            extensions: ["ipa"],
            utTypes: resolvedUTTypes(
                identifiers: ["com.apple.itunes.ipa", "public.zip-archive", "public.data"],
                filenameExtensions: ["ipa"]
            ),
            contentType: "com.apple.itunes.ipa"
        ),
        FileType(
            name: "Certificates",
            extensions: ["p12", "pfx"],
            utTypes: resolvedUTTypes(
                identifiers: ["com.rsa.pkcs-12", "com.microsoft.pfx", "public.data"],
                filenameExtensions: ["p12", "pfx"]
            ),
            contentType: "com.rsa.pkcs-12"
        ),
        FileType(
            name: "Provisioning Profiles",
            extensions: ["mobileprovision"],
            utTypes: resolvedUTTypes(
                identifiers: ["com.apple.mobileprovision", "public.data"],
                filenameExtensions: ["mobileprovision"]
            ),
            contentType: "com.apple.mobileprovision"
        ),
        FileType(
            name: "Local Models",
            extensions: ["gguf", "mlx", "safetensors"],
            utTypes: resolvedUTTypes(
                identifiers: ["com.freesign.local-model", "public.data"],
                filenameExtensions: ["gguf", "mlx", "safetensors"]
            ),
            contentType: "com.freesign.local-model"
        )
    ]
    
    /// Get UTTypes for a specific file type
    static func utTypes(for fileType: FileType) -> [UTType] {
        return fileType.utTypes
    }
    
    /// Get UTTypes for file import (all supported types)
    static var importUTTypes: [UTType] {
        return supportedFileTypes.flatMap { $0.utTypes }.removingDuplicates()
    }
    
    // MARK: - File Type Detection
    
    /// Detect the file type from a URL
    static func detectFileType(from url: URL) -> FileType? {
        let fileExtension = url.pathExtension.lowercased()
        
        for fileType in supportedFileTypes {
            if fileType.extensions.contains(fileExtension) {
                return fileType
            }
        }
        
        return nil
    }
    
    // MARK: - Import Handling
    
    /// Handle an incoming file URL ("Open with" / share sheet / onOpenURL).
    /// - Parameter url: The file URL to import
    /// - Returns: True if the file was handled successfully
    @discardableResult
    func handleFileURL(_ url: URL) -> Bool {
        // SwiftUI's onOpenURL and the AppDelegate callback both fire for the
        // same "Open with" event — skip the duplicate.
        if let last = lastHandledURL, last == url, Date().timeIntervalSince(lastHandledDate) < 3 {
            return true
        }
        lastHandledURL = url
        lastHandledDate = Date()

        guard let fileType = FileImporter.detectFileType(from: url) else {
            print("Unsupported file type: \(url.pathExtension)")
            return false
        }

        lastImportError = nil

        // The sandbox extension for an "Open with" URL is only guaranteed valid
        // during the callback, so the copy must happen synchronously right here.
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        do {
            let localURL: URL
            switch fileType.contentType {
            case "com.apple.itunes.ipa":
                localURL = try StorageManager.shared.storeIPA(from: url)
            case "com.rsa.pkcs-12":
                localURL = try StorageManager.shared.storeP12(from: url)
            case "com.apple.mobileprovision":
                localURL = try StorageManager.shared.storeMobileProvision(from: url)
            case "com.freesign.local-model":
                localURL = try StorageManager.shared.storeLocalModel(from: url)
            default:
                return false
            }

            // Show the sandboxed copy in the progress sheet, not the external URL
            // whose sandbox extension is about to expire.
            currentFileURL = localURL

            Task {
                await MainActor.run { isImporting = true }
                do {
                    switch fileType.contentType {
                    case "com.apple.itunes.ipa":
                        try await importIPABackground(fromLocalURL: localURL)
                    case "com.rsa.pkcs-12":
                        try await importCertificateBackground(fromLocalURL: localURL)
                    case "com.apple.mobileprovision":
                        try await importProvisioningProfileBackground(fromLocalURL: localURL)
                    case "com.freesign.local-model":
                        try await importLocalModelBackground(fromLocalURL: localURL)
                    default:
                        break
                    }
                } catch {
                    await MainActor.run {
                        lastImportError = error.localizedDescription
                        importProgress = "Import failed"
                    }
                }
            }
            return true
        } catch {
            lastImportError = error.localizedDescription
            print("Failed to copy file to sandbox: \(error)")
            return false
        }
    }
    
    // MARK: - IPA Import
    
    private func importIPABackground(fromLocalURL url: URL) async throws {
        await MainActor.run {
            isImporting = true
            importProgress = "Analyzing bundle…"
        }
        
        defer {
            Task { @MainActor in
                isImporting = false
            }
        }
        
        do {
            // Analyze the IPA
            let meta = try IPAAnalyzer.shared.analyze(ipaPath: url.path)
            
            // Cache the icon
            let appID = UUID()
            if let iconData = meta.iconData {
                StorageManager.shared.storeIcon(iconData, appID: appID)
            }
            let iconPath = meta.iconData != nil
                ? StorageManager.shared.iconsURL
                    .appendingPathComponent(appID.uuidString + ".png").path
                : nil
            
            // Build AppInfo model
            let app = AppInfo(
                id: appID,
                name: meta.name,
                bundleID: meta.bundleID,
                version: meta.version,
                buildNumber: meta.buildNumber,
                minOSVersion: meta.minOSVersion,
                ipaPath: url.path,
                iconPath: iconPath,
                fileSize: meta.fileSize,
                architectures: meta.architectures,
                embeddedFrameworks: meta.embeddedFrameworks,
                isEncrypted: meta.isEncrypted,
                isSigned: meta.isSigned,
                isFavorite: false,
                tags: [],
                dateImported: Date(),
                sourceURL: nil
            )
            
            // Persist
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) {
                    AppDataManager.shared.addImportedApp(app)
                }
                importProgress = "Import complete!"
            }
        } catch {
            // Clean up sandbox copy on failure
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }
    
    // MARK: - Certificate Import
    
    private func importCertificateBackground(fromLocalURL url: URL) async throws {
        await MainActor.run {
            isImporting = true
            importProgress = "Reading certificate…"
        }
        
        defer {
            Task { @MainActor in
                isImporting = false
            }
        }
        
        do {
            // Extract certificate metadata
            let certInfo = try ZSignWrapper.certificateInfo(fromP12: url.path, password: nil)
            
            // Build Certificate model
            let cn = certInfo["commonName"] as? String
                  ?? certInfo["subject"] as? String
                  ?? url.deletingPathExtension().lastPathComponent
            
            let certType: CertType = cn.hasPrefix("Apple Development") || cn.contains("Developer") ? .development :
                                  cn.hasPrefix("Apple Distribution") || cn.contains("Distribution") ? .distribution :
                                  cn.contains("Enterprise") || cn.contains("In-House") ? .enterprise : .unknown
            
            let expiry = certInfo["expirationDate"] as? Date ?? Date().addingTimeInterval(365 * 24 * 3600)
            let teamID = certInfo["teamID"] as? String ?? "Unknown"
            let teamName = certInfo["orgName"] as? String ?? ""
            let serial = certInfo["serialNumber"] as? String ?? ""
            
            let cert = Certificate(
                id: UUID(),
                name: cn,
                teamName: teamName,
                teamID: teamID,
                serialNumber: serial,
                certType: certType,
                p12Path: url.path,
                password: "",
                provisioningProfiles: [],
                expirationDate: expiry,
                dateAdded: Date()
            )
            
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) {
                    AppDataManager.shared.addCertificate(cert)
                }
                importProgress = "Certificate imported!"
            }
        } catch {
            // Clean up sandbox copy on failure
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }
    
    // MARK: - Provisioning Profile Import
    
    private func importProvisioningProfileBackground(fromLocalURL url: URL) async throws {
        await MainActor.run {
            isImporting = true
            importProgress = "Reading provisioning profile…"
        }
        
        defer {
            Task { @MainActor in
                isImporting = false
            }
        }
        
        do {
            // Parse the provisioning profile
            let profile = try ProvisioningProfileParser.parse(at: url.path)
            
            // If we have certificates, attach to the first one
            if let firstCert = AppDataManager.shared.certificates.first {
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.25)) {
                        AppDataManager.shared.addProfile(profile, toCertificate: firstCert.id)
                    }
                    importProgress = "Provisioning profile imported!"
                }
            } else {
                await MainActor.run {
                    importProgress = "No certificates available. Profile will be attached when you import a certificate."
                }
            }
        } catch {
            // Clean up sandbox copy on failure
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }
    // MARK: - Local Model Import
    
    private func importLocalModelBackground(fromLocalURL url: URL) async throws {
        await MainActor.run {
            isImporting = true
            importProgress = "Importing model…"
        }
        
        defer {
            Task { @MainActor in
                isImporting = false
            }
        }
        
        // The model file was already copied into the sandbox by StorageManager;
        // model weights are opaque binaries, so there is nothing to analyze.
        // Verify the copy exists, then surface it in the Files tab.
        guard StorageManager.shared.fileExists(at: url.path) else {
            throw ImportError.copyFailed
        }
        
        await MainActor.run {
            importProgress = "Model imported — pick it in Lab Assistant → Local Model provider."
        }
    }
}

// MARK: - File Type Model

struct FileType {
    let name: String
    let extensions: [String]
    let utTypes: [UTType]
    let contentType: String
}

// MARK: - Import Errors

enum ImportError: LocalizedError {
    case notAnIPA
    case notACertificate
    case notAProvisioningProfile
    case unsupportedFileType
    case fileAccessDenied
    case copyFailed
    case analysisFailed
    
    var errorDescription: String? {
        switch self {
        case .notAnIPA: return "The selected file is not a valid IPA archive."
        case .notACertificate: return "The selected file is not a valid certificate (P12/PFX)."
        case .notAProvisioningProfile: return "The selected file is not a valid provisioning profile."
        case .unsupportedFileType: return "This file type is not supported."
        case .fileAccessDenied: return "Access to the file was denied. Please try again."
        case .copyFailed: return "Failed to copy the file. Please check storage permissions."
        case .analysisFailed: return "Failed to analyze the IPA file. It may be corrupted."
        }
    }
}

// MARK: - Array Extension for Removing Duplicates

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}