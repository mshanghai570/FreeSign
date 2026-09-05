import Foundation

// MARK: - Source

/// A repository URL that vends a list of apps (AltStore-compatible JSON schema).
struct Source: Identifiable, Codable, Equatable {

    let id: UUID
    var name: String
    var url: String
    var iconURL: String?
    var description: String?
    var dateAdded: Date
    var lastFetched: Date?

    /// Apps fetched from this source on the last refresh.
    var apps: [SourceApp]

    // MARK: - Equatable

    static func == (lhs: Source, rhs: Source) -> Bool { lhs.id == rhs.id }
}

// MARK: - SourceApp

/// One app entry returned by a source JSON feed.
struct SourceApp: Identifiable, Codable, Equatable, Hashable {

    let id: UUID

    // Core metadata
    var name: String
    var bundleID: String
    var developerName: String
    var version: String
    var versionDate: Date?
    var size: Int64?
    var iconURL: String?
    var downloadURL: String
    var localizedDescription: String?
    var category: String?
    var minOSVersion: String?
    var permissions: [AppPermission]

    // Computed
    var formattedSize: String? {
        guard let s = size else { return nil }
        return ByteCountFormatter.string(fromByteCount: s, countStyle: .file)
    }

    static func == (lhs: SourceApp, rhs: SourceApp) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - AppPermission

struct AppPermission: Codable, Equatable, Identifiable {
    var id: String { type }
    let type: String         // e.g. "NSCameraUsageDescription"
    let usageDescription: String
}
