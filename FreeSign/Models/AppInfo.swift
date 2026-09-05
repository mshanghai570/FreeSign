import Foundation

/// Represents an IPA that has been imported into FreeSign's library.
/// All binary/icon data is stored on disk; this struct is JSON-serializable.
struct AppInfo: Identifiable, Codable, Hashable {

    // MARK: - Identity

    let id: UUID
    var name: String
    var bundleID: String
    var version: String
    var buildNumber: String        // CFBundleVersion (the numeric build)
    var minOSVersion: String

    // MARK: - Storage

    /// Absolute path to the IPA inside Documents/IPAs/.
    var ipaPath: String

    /// Absolute path to the cached icon PNG inside Documents/Icons/.
    /// Nil if no icon was extracted.
    var iconPath: String?

    // MARK: - Analysis

    var fileSize: Int64
    var architectures: [String]          // e.g. ["arm64", "arm64e"]
    var embeddedFrameworks: [String]     // framework/dylib names found in Payload/*.app/Frameworks/
    var isEncrypted: Bool                // FairPlay-encrypted (LC_ENCRYPTION_INFO present)
    var isSigned: Bool                   // has a valid code signature embedded

    // MARK: - Organization

    var isFavorite: Bool
    var tags: [String]
    var dateImported: Date
    var sourceURL: String?               // nil for locally imported IPAs

    // MARK: - Signing History

    var lastSignedWith: String?          // certificate CN
    var lastSignedDate: Date?

    // MARK: - Convenience

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var architectureString: String {
        architectures.isEmpty ? "Unknown" : architectures.joined(separator: ", ")
    }

    // MARK: - Backward-compat computed properties
    // Existing views/managers that haven't been migrated yet may still use these.

    /// Alias for ipaPath — kept so SigningManager can call `app.filePath` unchanged.
    var filePath: String { ipaPath }

    /// Loads icon PNG data from the icon cache on demand.
    /// Prefer loading via `iconPath` + UIImage directly in performance-sensitive views.
    var iconData: Data? {
        guard let path = iconPath else { return nil }
        return try? Data(contentsOf: URL(fileURLWithPath: path))
    }

    // MARK: - Equatable / Hashable

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
