import Foundation

// MARK: - Certificate

/// A signing identity — one P12 certificate that may carry multiple provisioning profiles.
struct Certificate: Identifiable, Codable, Equatable {

    // MARK: - Identity

    let id: UUID
    var name: String              // Common name from the X.509 certificate
    var teamName: String          // Organization / company name
    var teamID: String            // 10-char Apple Team ID
    var serialNumber: String      // Certificate serial number (hex string)
    var certType: CertType

    // MARK: - Storage (paths inside Documents/Certificates/)

    var p12Path: String
    var password: String          // stored in plaintext for now; keychain in a future pass

    // MARK: - Provisioning Profiles

    var provisioningProfiles: [ProvisioningProfile]

    // MARK: - Dates

    var expirationDate: Date
    var dateAdded: Date

    // MARK: - Computed

    var isExpired: Bool { expirationDate < Date() }

    var daysUntilExpiry: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
    }

    var primaryProfile: ProvisioningProfile? { provisioningProfiles.first }

    // MARK: - Equatable

    static func == (lhs: Certificate, rhs: Certificate) -> Bool { lhs.id == rhs.id }
}

// MARK: - CertType

enum CertType: String, Codable, CaseIterable {
    case development   = "iPhone Developer"
    case distribution  = "iPhone Distribution"
    case adhoc         = "Ad Hoc"
    case enterprise    = "Enterprise"
    case unknown       = "Unknown"

    var displayName: String { rawValue }

    var iconName: String {
        switch self {
        case .development:  return "hammer"
        case .distribution: return "arrow.up.to.line"
        case .adhoc:        return "person.2"
        case .enterprise:   return "building.2"
        case .unknown:      return "questionmark.circle"
        }
    }
}

// MARK: - ProvisioningProfile

/// A .mobileprovision file linked to a certificate.
struct ProvisioningProfile: Identifiable, Codable, Equatable {

    let id: UUID
    var name: String
    var path: String              // inside Documents/Certificates/
    var teamID: String
    var appIDName: String
    var bundleID: String          // may be wildcard e.g. "com.example.*"
    var expirationDate: Date
    var platforms: [String]       // e.g. ["iOS"]

    /// Entitlements extracted from the profile for display/edit.
    var entitlements: [String: String]

    var isWildcard: Bool { bundleID.hasSuffix(".*") || bundleID == "*" }
    var isExpired: Bool  { expirationDate < Date() }

    var daysUntilExpiry: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
    }

    static func == (lhs: ProvisioningProfile, rhs: ProvisioningProfile) -> Bool { lhs.id == rhs.id }
}
