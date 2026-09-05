import Foundation
import UIKit

// MARK: - LocalizedDescribable

protocol LocalizedDescribable {
    var localizedDescription: String { get }
}

extension LocalizedDescribable where Self: RawRepresentable, RawValue == String {
    var localizedDescription: String {
        self.rawValue
    }
}

// MARK: - Options

/// Global signing options that persist across sessions, mirroring Feather's OptionsManager.
/// These are the default rules applied to every signing job unless overridden per-session.
struct Options: Codable, Equatable {

    // MARK: Pre Modifications

    /// Custom app name override (nil = use the IPA's original name)
    var appName: String?
    /// Custom app version override
    var appVersion: String?
    /// Custom bundle identifier override
    var appIdentifier: String?
    /// Custom entitlements file URL
    var appEntitlementsFile: URL?
    /// App appearance (Light / Dark / Default)
    var appAppearance: AppAppearance
    /// Minimum iOS version requirement
    var minimumAppRequirement: MinimumAppRequirement
    /// Signing type (Default / Modify only)
    var signingOption: SigningOption

    // MARK: Options

    /// Inject path (@executable_path / @rpath)
    var injectPath: InjectPath
    /// Inject folder (/)
    var injectFolder: InjectFolder
    /// Random string appended to bundle identifiers for PPQ protection
    var ppqString: String
    /// Basic protection against PPQ
    var ppqProtection: Bool
    /// (Better) protection against PPQ
    var dynamicProtection: Bool
    /// Bundle identifiers that match and get replaced
    var identifiers: [String: String]
    /// Display names that match and get replaced
    var displayNames: [String: String]
    /// Files (.dylib, .deb) to extract and inject
    var injectionFiles: [URL]
    /// Mach-o load paths to remove
    var disInjectionFiles: [String]
    /// Files to remove from the bundle
    var removeFiles: [String]
    /// Force-enable file sharing
    var fileSharing: Bool
    /// Force-enable iTunes file sharing
    var itunesFileSharing: Bool
    /// ProMotion support
    var proMotion: Bool
    /// Game Mode support
    var gameMode: Bool
    /// iPad fullscreen
    var ipadFullscreen: Bool
    /// Remove URL schemes
    var removeURLScheme: Bool
    /// Remove embedded provisioning
    var removeProvisioning: Bool
    /// Remove app extensions
    var removeExtensions: Bool
    /// Remove watch app
    var removeWatchApp: Bool
    /// Remove supported devices
    var removeUISupportedDevices: Bool
    /// Enable documents
    var enableDocuments: Bool
    /// Weak inject dylibs
    var weakInject: Bool
    /// Ad-hoc signing
    var isAdhoc: Bool
    /// Force re-sign
    var forceResign: Bool
    /// Force localize display name files
    var changeLanguageFilesForCustomDisplayName: Bool
    /// Inject tweaks into extensions
    var injectIntoExtensions: Bool
    /// Install app after signing
    var installAfterSigning: Bool
    /// Share app after signing
    var shareAfterSigning: Bool

    // MARK: Experiments

    /// Enable Liquid Glass support (iOS 26+)
    var experiment_supportLiquidGlass: Bool
    /// Disable Liquid Glass
    var experiment_disableLiquidGlass: Bool
    /// Replace CydiaSubstrate with ElleKit
    var experiment_replaceSubstrateWithEllekit: Bool

    // MARK: Post Modifications

    /// Install app after signing completes
    var post_installAppAfterSigned: Bool
    /// Delete imported app after signing to save space
    var post_deleteAppAfterSigned: Bool

    // MARK: - Defaults

    static let defaultOptions = Options(
        appName: nil,
        appVersion: nil,
        appIdentifier: nil,
        appEntitlementsFile: nil,
        appAppearance: .default,
        minimumAppRequirement: .default,
        signingOption: .default,
        injectPath: .executable_path,
        injectFolder: .frameworks,
        ppqString: randomString(),
        ppqProtection: false,
        dynamicProtection: false,
        identifiers: [:],
        displayNames: [:],
        injectionFiles: [],
        disInjectionFiles: [],
        removeFiles: [],
        fileSharing: false,
        itunesFileSharing: false,
        proMotion: false,
        gameMode: false,
        ipadFullscreen: false,
        removeURLScheme: false,
        removeProvisioning: false,
        removeExtensions: false,
        removeWatchApp: false,
        removeUISupportedDevices: false,
        enableDocuments: false,
        weakInject: false,
        isAdhoc: false,
        forceResign: true,
        changeLanguageFilesForCustomDisplayName: false,
        injectIntoExtensions: false,
        installAfterSigning: false,
        shareAfterSigning: false,
        experiment_supportLiquidGlass: false,
        experiment_disableLiquidGlass: false,
        experiment_replaceSubstrateWithEllekit: false,
        post_installAppAfterSigned: false,
        post_deleteAppAfterSigned: false
    )

    // MARK: - Enums

    enum AppAppearance: String, Codable, CaseIterable, LocalizedDescribable {
        case `default`
        case light = "Light"
        case dark = "Dark"

        var localizedDescription: String {
            switch self {
            case .default: return "Default"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
    }

    enum MinimumAppRequirement: String, Codable, CaseIterable, LocalizedDescribable {
        case `default`
        case v16 = "16.0"
        case v15 = "15.0"
        case v14 = "14.0"
        case v13 = "13.0"
        case v12 = "12.0"

        var localizedDescription: String {
            switch self {
            case .default: return "Default"
            case .v16: return "16.0"
            case .v15: return "15.0"
            case .v14: return "14.0"
            case .v13: return "13.0"
            case .v12: return "12.0"
            }
        }
    }

    enum SigningOption: String, Codable, CaseIterable, LocalizedDescribable {
        case `default`
        case onlyModify

        var localizedDescription: String {
            switch self {
            case .default: return "Default"
            case .onlyModify: return "Modify"
            }
        }
    }

    enum InjectPath: String, Codable, CaseIterable, Hashable, LocalizedDescribable {
        case executable_path = "@executable_path"
        case rpath = "@rpath"
    }

    enum InjectFolder: String, Codable, CaseIterable, Hashable, LocalizedDescribable {
        case root = "/"
        case frameworks = "/Frameworks/"
    }

    /// Default random value for ppqString
    static func randomString() -> String {
        String((0..<6).compactMap { _ in UUID().uuidString.randomElement() })
    }
}

// MARK: - OptionsManager

/// Global manager for persistent signing options, mirroring Feather's OptionsManager.
final class OptionsManager: ObservableObject {
    static let shared = OptionsManager()

    @Published var options: Options
    private let _key = "signing_options"

    init() {
        if let data = UserDefaults.standard.data(forKey: _key),
           let savedOptions = try? JSONDecoder().decode(Options.self, from: data) {
            self.options = savedOptions
        } else {
            self.options = Options.defaultOptions
            self.saveOptions()
        }
    }

    /// Saves options to persistent storage
    func saveOptions() {
        if let encoded = try? JSONEncoder().encode(options) {
            UserDefaults.standard.set(encoded, forKey: _key)
            objectWillChange.send()
        }
    }

    /// Resets options to their defaults
    func resetToDefaults() {
        options = Options.defaultOptions
        saveOptions()
    }
}

