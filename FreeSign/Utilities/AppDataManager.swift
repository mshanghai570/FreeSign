import Foundation
import Combine

// MARK: - Database Container

/// The single JSON document persisted to Documents/metadata.json.
private struct AppDatabase: Codable {
    var importedApps:  [AppInfo]          = []
    var installedApps: [InstalledApp]     = []
    var certificates:  [Certificate]      = []
    var sources:       [Source]           = []
    var files:         [FileItem]         = []
}

// MARK: - AppDataManager

/// Central data store for the app.
/// Persists to a JSON file in the app's Documents directory — no UserDefaults size limits.
final class AppDataManager: ObservableObject {

    static let shared = AppDataManager()

    // Published collections — SwiftUI observes these
    @Published var importedApps:  [AppInfo]      = []
    @Published var installedApps: [InstalledApp] = []
    @Published var certificates:  [Certificate]  = []
    @Published var sources:       [Source]        = []
    @Published var files:         [FileItem]      = []

    // MARK: - Private

    private let storage = StorageManager.shared
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting     = .prettyPrinted
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Init

    private init() {
        load()
        // Free any leftover extractions from a previous session
        storage.cleanupAllExtracts()
        createDemoFilesIfNeeded()
    }

    // MARK: - Demo Files

    private func createDemoFilesIfNeeded() {
        let demoURL = storage.documentsURL.appendingPathComponent("Welcome to FreeSign.txt")
        guard !FileManager.default.fileExists(atPath: demoURL.path) else { return }

        let welcomeText = """
        Welcome to FreeSign!

        This is your Documents folder. You can import IPAs, certificates,
        provisioning profiles, models, and other files here.

        Quick start:
        1. Tap the + button to import files
        2. Use the Files tab to browse and manage them
        3. Open Settings to configure themes and developer options
        """

        try? welcomeText.write(to: demoURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Imported Apps

    func addImportedApp(_ app: AppInfo) {
        importedApps.insert(app, at: 0)
        save()
    }

    func updateImportedApp(_ app: AppInfo) {
        guard let idx = importedApps.firstIndex(where: { $0.id == app.id }) else { return }
        importedApps[idx] = app
        save()
    }

    func removeImportedApp(_ app: AppInfo) {
        // Delete the IPA file and its cached icon
        storage.deleteFile(at: app.ipaPath)
        if let iconPath = app.iconPath { storage.deleteFile(at: iconPath) }
        storage.deleteIcon(appID: app.id)

        importedApps.removeAll { $0.id == app.id }
        save()
    }

    // MARK: - Installed (Signed) Apps

    func addInstalledApp(_ app: InstalledApp) {
        installedApps.insert(app, at: 0)
        save()
    }

    func updateInstalledApp(_ app: InstalledApp) {
        guard let idx = installedApps.firstIndex(where: { $0.id == app.id }) else { return }
        installedApps[idx] = app
        save()
    }

    func removeInstalledApp(_ app: InstalledApp) {
        if let signed = app.signedIPA { storage.deleteFile(at: signed) }
        storage.deleteIcon(appID: app.id)
        installedApps.removeAll { $0.id == app.id }
        save()
    }

    // MARK: - Certificates

    func addCertificate(_ cert: Certificate) {
        certificates.insert(cert, at: 0)
        save()
    }

    func updateCertificate(_ cert: Certificate) {
        guard let idx = certificates.firstIndex(where: { $0.id == cert.id }) else { return }
        certificates[idx] = cert
        save()
    }

    func removeCertificate(_ cert: Certificate) {
        storage.deleteFile(at: cert.p12Path)
        cert.provisioningProfiles.forEach { storage.deleteFile(at: $0.path) }
        certificates.removeAll { $0.id == cert.id }
        save()
    }

    /// Attach a provisioning profile to an existing certificate.
    func addProfile(_ profile: ProvisioningProfile, toCertificate certID: UUID) {
        guard let idx = certificates.firstIndex(where: { $0.id == certID }) else { return }
        certificates[idx].provisioningProfiles.append(profile)
        save()
    }

    func removeProfile(_ profile: ProvisioningProfile, fromCertificate certID: UUID) {
        guard let idx = certificates.firstIndex(where: { $0.id == certID }) else { return }
        storage.deleteFile(at: profile.path)
        certificates[idx].provisioningProfiles.removeAll { $0.id == profile.id }
        save()
    }

    // MARK: - Sources

    func addSource(_ source: Source) {
        sources.append(source)
        save()
    }

    func updateSource(_ source: Source) {
        guard let idx = sources.firstIndex(where: { $0.id == source.id }) else { return }
        sources[idx] = source
        save()
    }

    /// Replace the cached apps of an existing source, matched by URL.
    /// The fetcher returns a fresh Source with a new id, so refreshes must
    /// match on the source URL rather than the id.
    func updateSource(byURL url: String, with source: Source) {
        guard let idx = sources.firstIndex(where: { $0.url == url }) else { return }
        sources[idx] = source
        save()
    }

    func removeSource(_ source: Source) {
        sources.removeAll { $0.id == source.id }
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: storage.metadataURL) else { return }
        guard let db   = try? decoder.decode(AppDatabase.self, from: data) else {
            print("[AppDataManager] Failed to decode metadata.json — starting fresh.")
            return
        }
        importedApps  = db.importedApps
        installedApps = db.installedApps
        certificates  = db.certificates
        sources       = db.sources
        files         = db.files
    }

    func save() {
        let db = AppDatabase(
            importedApps:  importedApps,
            installedApps: installedApps,
            certificates:  certificates,
            sources:       sources,
            files:         files
        )
        do {
            let data = try encoder.encode(db)
            try data.write(to: storage.metadataURL, options: .atomic)
        } catch {
            print("[AppDataManager] Save failed: \(error)")
        }
    }

    // MARK: - Convenience Queries

    func certificate(id: UUID) -> Certificate? {
        certificates.first { $0.id == id }
    }

    func importedApp(id: UUID) -> AppInfo? {
        importedApps.first { $0.id == id }
    }

    var validCertificates: [Certificate] {
        certificates.filter { !$0.isExpired }
    }

    var expiringSoonCertificates: [Certificate] {
        certificates.filter { !$0.isExpired && $0.daysUntilExpiry < 14 }
    }
}

// MARK: - Backward-compat stub (removes old broken extension from CertificatesView)

extension AppDataManager {
    /// No-op kept for source compatibility. All saves now happen automatically.
    func saveAll() { save() }
}
