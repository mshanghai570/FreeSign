import Foundation

// MARK: - Provisioning Profile Parser

/// Parses .mobileprovision files (which are CMS-wrapped plists).
/// Provisioning profiles contain team info, app IDs, entitlements, and expiry dates.
enum ProvisioningProfileParser {
    
    // MARK: - Errors
    
    enum ProfileError: LocalizedError {
        case invalidFormat
        case parseFailed
        case missingData
        
        var errorDescription: String? {
            switch self {
            case .invalidFormat: return "Provisioning profile has invalid format (not a valid .mobileprovision file)."
            case .parseFailed:    return "Failed to parse provisioning profile data."
            case .missingData:    return "Provisioning profile is missing required data."
            }
        }
    }
    
    // MARK: - Public API
    
    /// Parse a provisioning profile from a file path.
    /// - Parameter path: Absolute path to the .mobileprovision file
    /// - Returns: ProvisioningProfile model
    /// - Throws: ProfileError on failure
    static func parse(at path: String) throws -> ProvisioningProfile {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try parse(data: data, path: path)
    }
    
    /// Parse a provisioning profile from raw data.
    /// - Parameters:
    ///   - data: Raw .mobileprovision file data
    ///   - path: Path to store in the model (for reference)
    /// - Returns: ProvisioningProfile model
    /// - Throws: ProfileError on failure
    static func parse(data: Data, path: String) throws -> ProvisioningProfile {
        // Provisioning profiles are CMS-wrapped plists. We extract the XML payload
        // by searching for the plist XML between the CMS envelope bytes.
        guard let xmlStart = data.range(of: Data("<?xml".utf8)),
              let xmlEnd   = data.range(of: Data("</plist>".utf8)) else {
            throw ProfileError.invalidFormat
        }

        let xmlRange = xmlStart.lowerBound..<xmlEnd.upperBound
        let xmlData  = data.subdata(in: xmlRange)

        guard let dict = try? PropertyListSerialization.propertyList(
            from: xmlData, options: [], format: nil
        ) as? [String: Any] else {
            throw ProfileError.parseFailed
        }

        return buildProfile(from: dict, path: path)
    }
    
    // MARK: - Profile Building
    
    private static func buildProfile(from dict: [String: Any], path: String) -> ProvisioningProfile {
        let name      = dict["Name"]               as? String ?? "Unknown Profile"
        let teamID    = (dict["TeamIdentifier"] as? [String])?.first ?? "Unknown"
        let appIDName = dict["AppIDName"]           as? String ?? ""
        let expiry    = dict["ExpirationDate"]      as? Date   ?? Date().addingTimeInterval(365 * 86400)
        let platforms = dict["Platform"]            as? [String] ?? ["iOS"]

        // Extract bundle ID from entitlements
        var bundleID = "*"
        var entitlementStrings: [String: String] = [:]
        if let ents = dict["Entitlements"] as? [String: Any] {
            bundleID = ents["application-identifier"] as? String ?? "*"
            // Strip the team prefix from the bundle ID: "TEAMID.com.example.*" → "com.example.*"
            if bundleID.contains(".") {
                bundleID = String(bundleID.split(separator: ".", maxSplits: 1).last ?? Substring(bundleID))
            }
            for (k, v) in ents {
                entitlementStrings[k] = "\(v)"
            }
        }

        return ProvisioningProfile(
            id:               UUID(),
            name:             name,
            path:             path,
            teamID:           teamID,
            appIDName:        appIDName,
            bundleID:         bundleID,
            expirationDate:   expiry,
            platforms:        platforms,
            entitlements:     entitlementStrings
        )
    }
}