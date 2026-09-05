import Foundation

/// Owns the persistent on-disk layout inside the app's Documents container.
///
/// Directory structure:
/// ```
/// Documents/
/// ├── IPAs/          Imported IPA files (permanent)
/// ├── Signed/        Signed IPA output files
/// ├── Certificates/  P12 and .mobileprovision files
/// ├── Models/        Imported local model files (GGUF / MLX)
/// ├── Icons/         Extracted app icon PNGs (cached by AppInfo.id)
/// ├── Extracts/      Temporary IPA extractions (cleaned up after use)
/// └── metadata.json  JSON-encoded AppDatabase
/// ```
final class StorageManager {

    static let shared = StorageManager()

    private let fm = FileManager.default

    // MARK: - Root URLs

    let documentsURL: URL
    let ipasURL: URL
    let signedURL: URL
    let certificatesURL: URL
    let modelsURL: URL
    let iconsURL: URL
    let extractsURL: URL
    let metadataURL: URL

    // MARK: - Init

    private init() {
        documentsURL = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        ipasURL          = documentsURL.appendingPathComponent("IPAs",         isDirectory: true)
        signedURL        = documentsURL.appendingPathComponent("Signed",       isDirectory: true)
        certificatesURL  = documentsURL.appendingPathComponent("Certificates", isDirectory: true)
        modelsURL        = documentsURL.appendingPathComponent("Models",       isDirectory: true)
        iconsURL         = documentsURL.appendingPathComponent("Icons",        isDirectory: true)
        extractsURL      = documentsURL.appendingPathComponent("Extracts",     isDirectory: true)
        metadataURL      = documentsURL.appendingPathComponent("metadata.json")
        createDirectories()
    }

    private func createDirectories() {
        [ipasURL, signedURL, certificatesURL, modelsURL, iconsURL, extractsURL].forEach {
            try? fm.createDirectory(at: $0, withIntermediateDirectories: true)
        }
    }

    // MARK: - IPA Storage

    /// Copy an IPA from a (possibly security-scoped) URL into our IPAs directory.
    /// Caller must already be inside `startAccessingSecurityScopedResource`.
    func storeIPA(from sourceURL: URL) throws -> URL {
        let dest = ipasURL.appendingPathComponent("\(UUID().uuidString).ipa")
        try fm.copyItem(at: sourceURL, to: dest)
        return dest
    }

    /// Move or copy a signed IPA output into the Signed directory.
    func storeSignedIPA(from sourceURL: URL, baseName: String) throws -> URL {
        let safe = baseName.replacingOccurrences(of: "/", with: "_")
        let dest = signedURL.appendingPathComponent("\(safe)_\(UUID().uuidString).ipa")
        if fm.fileExists(atPath: sourceURL.path) {
            try fm.moveItem(at: sourceURL, to: dest)
        }
        return dest
    }

    // MARK: - Certificate Storage

    /// Copy a .p12 from a security-scoped URL into Certificates/.
    func storeP12(from sourceURL: URL) throws -> URL {
        let dest = certificatesURL.appendingPathComponent("cert_\(UUID().uuidString).p12")
        try fm.copyItem(at: sourceURL, to: dest)
        return dest
    }

    /// Copy a .mobileprovision from a security-scoped URL into Certificates/.
    func storeMobileProvision(from sourceURL: URL) throws -> URL {
        let dest = certificatesURL.appendingPathComponent("prov_\(UUID().uuidString).mobileprovision")
        try fm.copyItem(at: sourceURL, to: dest)
        return dest
    }

    // MARK: - Local Model Storage

    /// Extensions recognized as local model files (GGUF / MLX).
    static let localModelExtensions: Set<String> = ["gguf", "mlx", "safetensors"]

    /// Copy a local model file (GGUF / MLX) from a security-scoped URL into Models/.
    /// The original file name is preserved because the Local Model provider sends it
    /// to the inference server as the `model` identifier.
    func storeLocalModel(from sourceURL: URL) throws -> URL {
        var dest = modelsURL.appendingPathComponent(sourceURL.lastPathComponent)
        if fm.fileExists(atPath: dest.path) {
            let name = sourceURL.deletingPathExtension().lastPathComponent
            let ext = sourceURL.pathExtension
            dest = modelsURL.appendingPathComponent("\(name)_\(UUID().uuidString.prefix(8)).\(ext)")
        }
        try fm.copyItem(at: sourceURL, to: dest)
        return dest
    }

    /// Recursively find every imported local model file (.gguf / .mlx / .safetensors)
    /// anywhere under Documents, so they can be picked in the Lab Assistant settings.
    /// Skipped directories are internal caches / outputs, not user content.
    func localModelFiles() -> [URL] {
        var results: [URL] = []
        let skippedDirectories: Set<String> = ["Extracts", "Icons", "Signed"]

        func walk(_ directory: URL) {
            guard let contents = try? fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return }

            for url in contents {
                var isDir: ObjCBool = false
                fm.fileExists(atPath: url.path, isDirectory: &isDir)
                if isDir.boolValue {
                    if !skippedDirectories.contains(url.lastPathComponent) {
                        walk(url)
                    }
                } else if Self.localModelExtensions.contains(url.pathExtension.lowercased()) {
                    results.append(url)
                }
            }
        }

        walk(documentsURL)
        return results.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    // MARK: - Icon Cache

    func storeIcon(_ data: Data, appID: UUID) {
        let dest = iconsURL.appendingPathComponent("\(appID.uuidString).png")
        try? data.write(to: dest, options: .atomic)
    }

    func loadIconData(appID: UUID) -> Data? {
        let url = iconsURL.appendingPathComponent("\(appID.uuidString).png")
        return try? Data(contentsOf: url)
    }

    func deleteIcon(appID: UUID) {
        let url = iconsURL.appendingPathComponent("\(appID.uuidString).png")
        try? fm.removeItem(at: url)
    }

    // MARK: - Extraction Workspace

    /// Create a fresh temporary directory under Extracts/ for one IPA unzip session.
    func newExtractDirectory() -> URL {
        let dir = extractsURL.appendingPathComponent("x_\(UUID().uuidString)", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Delete a single extract directory created by `newExtractDirectory`.
    func cleanupExtract(at url: URL) {
        try? fm.removeItem(at: url)
    }

    /// Wipe all extraction directories (on app launch to free space).
    func cleanupAllExtracts() {
        guard let contents = try? fm.contentsOfDirectory(at: extractsURL,
                                                          includingPropertiesForKeys: nil) else { return }
        contents.forEach { try? fm.removeItem(at: $0) }
    }

    // MARK: - Utilities

    func deleteFile(at path: String) {
        guard !path.isEmpty else { return }
        try? fm.removeItem(atPath: path)
    }

    func fileExists(at path: String) -> Bool {
        fm.fileExists(atPath: path)
    }

    func fileSize(at path: String) -> Int64 {
        guard let attrs = try? fm.attributesOfItem(atPath: path) else { return 0 }
        return attrs[.size] as? Int64 ?? 0
    }

    /// Human-readable byte count string.
    static func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
