import Foundation

/// An app that has been signed by FreeSign and lives in the Signed/ folder.
struct InstalledApp: Identifiable, Codable, Equatable {

    // MARK: - Identity

    let id: UUID
    var name: String
    var bundleID: String
    var version: String
    var buildNumber: String = ""    // default — SigningManager doesn't supply this yet

    // MARK: - Storage

    var originalIPA: String

    /// Path to the *signed* IPA in Documents/Signed/. Nil until signing completes.
    var signedIPA: String?           = nil

    /// Cached icon PNG path in Documents/Icons/.
    var iconPath: String?            = nil

    /// Raw icon PNG data, stored inline for signed apps.
    /// Set at signing time from the source IPA's icon or a user override.
    /// LibraryView reads this; future refactor will migrate to iconPath-based loading.
    var iconData: Data?              = nil

    // MARK: - State

    var isSigned: Bool
    var installDate: Date
    var signDate: Date?              = nil

    // MARK: - Signing Metadata (all optional with defaults so old callers compile)

    var signingCertName: String?     = nil
    var signingTeamID: String?       = nil
    var signingTeamName: String?     = nil
    var certExpirationDate: Date?    = nil

    // MARK: - Computed

    var isInstalled: Bool { signedIPA != nil && FileManager.default.fileExists(atPath: signedIPA ?? "") }

    var daysSinceSigned: Int? {
        guard let d = signDate else { return nil }
        return Calendar.current.dateComponents([.day], from: d, to: Date()).day
    }

    // MARK: - Equatable

    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool { lhs.id == rhs.id }
}
