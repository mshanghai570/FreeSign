import SwiftUI
import UniformTypeIdentifiers

// MARK: - File Importer Utility

/// Centralized file importing utility. Every externally selected file is copied
/// into the app container before asynchronous analysis begins, so Files sandbox
/// access never expires while a certificate or IPA is being processed.
final class FileImporter: ObservableObject {
    static let shared = FileImporter()

    @Published var isImporting = false
    @Published var importProgress = ""
    @Published var currentFileURL: URL?
    @Published var lastImportError: String?

    /// Direct File imports require a password before a P12 can be read. The
    /// app root presents the password sheet whenever this URL is non-nil.
    @Published var pendingCertificateURL: URL?
    @Published var pendingCertificateFileName = ""

    /// "Open with" events can reach both UIKit and SwiftUI. Keep a short
    /// dedupe window so a single external selection is never imported twice.
    private var lastHandledURL: URL?
    private var lastHandledDate = Date.distantPast

    private init() {}

    // MARK: - Supported file types

    private static func resolvedUTTypes(
        identifiers: [String],
        filenameExtensions: [String] = []
    ) -> [UTType] {
        var types: [UTType] = []
        for identifier in identifiers {
            if let type = UTType(identifier) { types.append(type) }
        }
        for fileExtension in filenameExtensions {
            if let type = UTType(filenameExtension: fileExtension) { types.append(type) }
        }
        if types.isEmpty { types.append(.data) }
        return types.removingDuplicates()
    }

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

    static func utTypes(for fileType: FileType) -> [UTType] { fileType.utTypes }
    static var importUTTypes: [UTType] { supportedFileTypes.flatMap(\.utTypes).removingDuplicates() }

    static func detectFileType(from url: URL) -> FileType? {
        let fileExtension = url.pathExtension.lowercased()
        return supportedFileTypes.first { $0.extensions.contains(fileExtension) }
    }

    // MARK: - External file handling

    /// Handles files delivered by the Files app, share sheet, document picker,
    /// or drag and drop. P12/PFX files first open a password sheet instead of
    /// being incorrectly attempted with an empty password.
    @discardableResult
    func handleFileURL(_ url: URL) -> Bool {
        if let last = lastHandledURL,
           last == url,
           Date().timeIntervalSince(lastHandledDate) < 3 {
            return true
        }
        lastHandledURL = url
        lastHandledDate = Date()

        guard let fileType = Self.detectFileType(from: url) else {
            lastImportError = "Unsupported file type: .\(url.pathExtension.isEmpty ? "unknown" : url.pathExtension)"
            return false
        }

        lastImportError = nil
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        do {
            switch fileType.contentType {
            case "com.rsa.pkcs-12":
                try prepareCertificateImport(from: url)
            case "com.apple.itunes.ipa":
                beginImport(localURL: try StorageManager.shared.storeIPA(from: url), contentType: fileType.contentType)
            case "com.apple.mobileprovision":
                beginImport(localURL: try StorageManager.shared.storeMobileProvision(from: url), contentType: fileType.contentType)
            case "com.freesign.local-model":
                beginImport(localURL: try StorageManager.shared.storeLocalModel(from: url), contentType: fileType.contentType)
            default:
                return false
            }
            return true
        } catch {
            lastImportError = "Failed to copy \(url.lastPathComponent): \(error.localizedDescription)"
            return false
        }
    }

    /// Queues a local P12/PFX selected from the Files tab. This follows the
    /// same password and validation path as an external "Open with FreeSign".
    func prepareCertificateImport(from url: URL) throws {
        let localURL = try StorageManager.shared.storeP12(from: url)
        pendingCertificateFileName = url.lastPathComponent
        pendingCertificateURL = localURL
        importProgress = "Enter the certificate password to continue."
    }

    func cancelPendingCertificateImport() {
        if let url = pendingCertificateURL {
            try? FileManager.default.removeItem(at: url)
        }
        pendingCertificateURL = nil
        pendingCertificateFileName = ""
    }

    /// Validates the copied certificate with the password supplied by the user
    /// and stores only the identity metadata in the app database.
    func importCertificate(fromLocalURL url: URL, password: String) {
        pendingCertificateURL = nil
        pendingCertificateFileName = ""
        lastImportError = nil
        currentFileURL = url
        isImporting = true
        importProgress = "Reading certificate…"

        Task.detached(priority: .userInitiated) {
            do {
                let certInfo = try ZSignWrapper.certificateInfo(
                    fromP12: url.path,
                    password: password.isEmpty ? nil : password
                )
                let certificate = Self.makeCertificate(from: certInfo, localURL: url, password: password)
                if !password.isEmpty {
                    let saved = await KeychainHelper.saveCertificatePassword(
                        certificateID: certificate.id,
                        password: password
                    )
                    if !saved {
                        throw ImportError.securePasswordStorageFailed
                    }
                }
                await MainActor.run {
                    AppDataManager.shared.addCertificate(certificate)
                    self.importProgress = "Certificate imported!"
                    self.isImporting = false
                }
            } catch {
                try? FileManager.default.removeItem(at: url)
                await MainActor.run {
                    self.lastImportError = "Failed to import certificate: \(error.localizedDescription)"
                    self.importProgress = "Certificate import failed"
                    self.isImporting = false
                }
            }
        }
    }

    // MARK: - Background imports

    private func beginImport(localURL: URL, contentType: String) {
        currentFileURL = localURL
        isImporting = true

        Task {
            do {
                switch contentType {
                case "com.apple.itunes.ipa":
                    try await importIPABackground(fromLocalURL: localURL)
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
                    isImporting = false
                }
            }
        }
    }

    private func importIPABackground(fromLocalURL url: URL) async throws {
        await MainActor.run { importProgress = "Analyzing bundle…" }
        defer { Task { @MainActor in isImporting = false } }

        do {
            let metadata = try await Task.detached(priority: .userInitiated) {
                try IPAAnalyzer.shared.analyze(ipaPath: url.path)
            }.value
            let appID = UUID()
            if let iconData = metadata.iconData {
                StorageManager.shared.storeIcon(iconData, appID: appID)
            }
            let iconPath = metadata.iconData == nil
                ? nil
                : StorageManager.shared.iconsURL.appendingPathComponent("\(appID.uuidString).png").path
            let app = AppInfo(
                id: appID,
                name: metadata.name,
                bundleID: metadata.bundleID,
                version: metadata.version,
                buildNumber: metadata.buildNumber,
                minOSVersion: metadata.minOSVersion,
                ipaPath: url.path,
                iconPath: iconPath,
                fileSize: metadata.fileSize,
                architectures: metadata.architectures,
                embeddedFrameworks: metadata.embeddedFrameworks,
                isEncrypted: metadata.isEncrypted,
                isSigned: metadata.isSigned,
                isFavorite: false,
                tags: [],
                dateImported: Date(),
                sourceURL: nil,
                lastSignedWith: nil,
                lastSignedDate: nil
            )
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) { AppDataManager.shared.addImportedApp(app) }
                importProgress = "Import complete!"
            }
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    private func importProvisioningProfileBackground(fromLocalURL url: URL) async throws {
        await MainActor.run { importProgress = "Reading provisioning profile…" }
        defer { Task { @MainActor in isImporting = false } }

        do {
            let profile = try await Task.detached(priority: .userInitiated) {
                try ProvisioningProfileParser.parse(at: url.path)
            }.value
            await MainActor.run {
                if let certificate = AppDataManager.shared.certificates.first(where: { !$0.isExpired })
                    ?? AppDataManager.shared.certificates.first {
                    AppDataManager.shared.addProfile(profile, toCertificate: certificate.id)
                    importProgress = "Provisioning profile imported!"
                } else {
                    lastImportError = "Import a .p12 certificate first, then add its provisioning profile."
                    importProgress = "Provisioning profile needs a certificate"
                    try? FileManager.default.removeItem(at: url)
                }
            }
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    private func importLocalModelBackground(fromLocalURL url: URL) async throws {
        await MainActor.run { importProgress = "Importing model…" }
        defer { Task { @MainActor in isImporting = false } }
        guard StorageManager.shared.fileExists(at: url.path) else { throw ImportError.copyFailed }
        await MainActor.run {
            importProgress = "Model imported — select it in Lab Assistant → Local Model provider."
        }
    }

    private static func makeCertificate(
        from certInfo: [AnyHashable: Any],
        localURL: URL,
        password: String
    ) -> Certificate {
        let commonName = certInfo["commonName"] as? String
            ?? certInfo["subject"] as? String
            ?? localURL.deletingPathExtension().lastPathComponent
        let certificateType: CertType
        if commonName.hasPrefix("Apple Development") || commonName.contains("Developer") {
            certificateType = .development
        } else if commonName.hasPrefix("Apple Distribution") || commonName.contains("Distribution") {
            certificateType = .distribution
        } else if commonName.contains("Enterprise") || commonName.contains("In-House") {
            certificateType = .enterprise
        } else {
            certificateType = .unknown
        }

        return Certificate(
            id: UUID(),
            name: commonName,
            teamName: certInfo["orgName"] as? String ?? "",
            teamID: certInfo["teamID"] as? String ?? "Unknown",
            serialNumber: certInfo["serialNumber"] as? String ?? "",
            certType: certificateType,
            p12Path: localURL.path,
            password: "",
            provisioningProfiles: [],
            expirationDate: certInfo["expirationDate"] as? Date ?? Date().addingTimeInterval(365 * 24 * 60 * 60),
            dateAdded: Date()
        )
    }
}

struct FileType {
    let name: String
    let extensions: [String]
    let utTypes: [UTType]
    let contentType: String
}

enum ImportError: LocalizedError {
    case unsupportedFileType
    case copyFailed
    case securePasswordStorageFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType: return "This file type is not supported."
        case .copyFailed: return "Failed to copy the file. Check available storage and try again."
        case .securePasswordStorageFailed: return "The certificate password could not be saved securely in the iOS Keychain."
        }
    }
}

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
