import Foundation

/// All configurable parameters for a signing job.
/// Mirrors the full feature set of ZSign's CLI flags.
struct SigningOptions: Codable {

    // MARK: - App Identity Overrides

    var appName: String?
    var appIdentifier: String?
    var appVersion: String?
    var appBuildNumber: String?
    var minOSVersion: String?

    // MARK: - Signing Behaviour

    /// Use ad-hoc signing (no real certificate needed; works with jailbreak/TrollStore).
    var isAdhoc: Bool = false

    /// Force-overwrite an existing code signature even if it looks valid.
    var forceResign: Bool = true

    /// Inject a custom entitlements plist, replacing the profile's entitlements.
    var entitlementsPath: String? = nil

    // MARK: - Bundle Modifications

    var removeExtensions: Bool = false
    var removeWatchApp: Bool = false
    var removeUISupportedDevices: Bool = false

    /// Adds UIFileSharingEnabled / LSSupportsOpeningDocumentsInPlace to Info.plist.
    var enableDocuments: Bool = false

    // MARK: - Dylib Management

    /// Paths to .dylib files to inject into the main executable (like optool inject).
    var injectDylibs: [String] = []

    /// Names of dylibs to strip from the bundle before signing.
    var removeDylibs: [String] = []

    /// Use @weak_import for injected dylibs (app still launches if dylib is missing).
    var weakInject: Bool = false

    // MARK: - Post-Signing

    /// Open the system export sheet after signing. A receiving sideloading app
    /// such as AltStore or SideStore performs the actual installation.
    var installAfterSigning: Bool = false

    /// Legacy preference retained for existing installs; it also opens the
    /// system export sheet after signing.
    var shareAfterSigning: Bool = false

    // MARK: - Custom .plist Entries

    /// Custom key-value pairs to add to Info.plist or entitlements.
    var customPlistEntries: [PlistEntry] = []
}

/// A custom key-value pair for Info.plist or entitlements.
struct PlistEntry: Identifiable, Codable {
    var id = UUID()
    var key: String
    var value: String
    var isEntitlement: Bool = false
    var type: PlistValueType = .string
}

/// Supported types for custom .plist entries.
enum PlistValueType: String, CaseIterable, Codable {
    case string, bool, number, array, dictionary
}
