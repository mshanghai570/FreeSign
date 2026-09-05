import Foundation

protocol AIContext: Codable {
    var sourceView: String { get }
    var action: AIAction { get }
    var summary: String { get }
    var payload: [String: Any] { get }
}

extension AIContext {
    var userFacingTitle: String {
        "\(action.displayName) — \(sourceView)"
    }
}

struct PlistEditorContext: AIContext {
    let sourceView: String
    let action: AIAction
    let filePath: String
    let keyPath: String
    let valueType: String
    let valuePreview: String
    let fullPlistSnippet: String?

    var summary: String {
        "Plist key '\(keyPath)' of type \(valueType) in \(filePath)"
    }

    var payload: [String: Any] {
        [
            "filePath": filePath,
            "keyPath": keyPath,
            "valueType": valueType,
            "valuePreview": valuePreview,
            "fullPlistSnippet": fullPlistSnippet ?? ""
        ]
    }
}

struct TextEditorContext: AIContext {
    let sourceView: String
    let action: AIAction
    let filePath: String
    let selectedRange: NSRange?
    let contentSnippet: String
    let fullContent: String?

    var summary: String {
        if let range = selectedRange, range.length > 0 {
            return "Selected text in \(filePath) (\(range.length) chars)"
        }
        return "File \(filePath)"
    }

    var payload: [String: Any] {
        [
            "filePath": filePath,
            "selectedRange": selectedRange?.description ?? "none",
            "contentSnippet": contentSnippet,
            "fullContent": fullContent ?? ""
        ]
    }
}

struct HexEditorContext: AIContext {
    let sourceView: String
    let action: AIAction
    let filePath: String
    let selectedOffset: Int?
    let hexDump: String
    let fileSize: Int64

    var summary: String {
        if let offset = selectedOffset {
            return "Hex at offset 0x\(String(offset, radix: 16)) in \(filePath)"
        }
        return "Hex view of \(filePath)"
    }

    var payload: [String: Any] {
        [
            "filePath": filePath,
            "selectedOffset": selectedOffset ?? 0,
            "hexDump": hexDump,
            "fileSize": fileSize
        ]
    }
}

struct SigningFailureContext: AIContext {
    let sourceView: String
    let action: AIAction
    let appName: String
    let bundleID: String
    let appVersion: String
    let selectedCertificateName: String?
    let certificateExpiry: Date?
    let statusMessage: String
    let optionsSummary: [String: String]

    var summary: String {
        "Signing failed for \(appName) (\(bundleID)): \(statusMessage)"
    }

    var payload: [String: Any] {
        [
            "appName": appName,
            "bundleID": bundleID,
            "appVersion": appVersion,
            "selectedCertificateName": selectedCertificateName ?? "none",
            "certificateExpiry": certificateExpiry?.ISO8601String() ?? "unknown",
            "statusMessage": statusMessage,
            "optionsSummary": optionsSummary
        ]
    }
}

struct BundleFileContext: AIContext {
    let sourceView: String
    let action: AIAction
    let filePath: String
    let fileName: String
    let fileSize: Int64
    let fileExtension: String
    let parentBundleID: String

    var summary: String {
        "File \(fileName) (\(fileExtension)) in bundle \(parentBundleID)"
    }

    var payload: [String: Any] {
        [
            "filePath": filePath,
            "fileName": fileName,
            "fileSize": fileSize,
            "fileExtension": fileExtension,
            "parentBundleID": parentBundleID
        ]
    }
}

struct AppInfoContext: AIContext {
    let sourceView: String
    let action: AIAction
    let appName: String
    let bundleID: String
    let version: String
    let architectures: [String]
    let isEncrypted: Bool
    let isSigned: Bool
    let embeddedFrameworks: [String]
    let signingHistory: [String: String]?

    var summary: String {
        "App \(appName) (\(bundleID)) v\(version)"
    }

    var payload: [String: Any] {
        [
            "appName": appName,
            "bundleID": bundleID,
            "version": version,
            "architectures": architectures,
            "isEncrypted": isEncrypted,
            "isSigned": isSigned,
            "embeddedFrameworks": embeddedFrameworks,
            "signingHistory": signingHistory ?? [:]
        ]
    }
}

struct CertificateContext: AIContext {
    let sourceView: String
    let action: AIAction
    let certificateName: String
    let certType: String
    let teamID: String
    let expiryDate: Date
    let daysUntilExpiry: Int
    let profileCount: Int
    let isExpired: Bool

    var summary: String {
        "Certificate '\(certificateName)' (\(certType)), expires in \(daysUntilExpiry) days"
    }

    var payload: [String: Any] {
        [
            "certificateName": certificateName,
            "certType": certType,
            "teamID": teamID,
            "expiryDate": expiryDate.ISO8601String(),
            "daysUntilExpiry": daysUntilExpiry,
            "profileCount": profileCount,
            "isExpired": isExpired
        ]
    }
}

struct DiagnosticContext: AIContext {
    let sourceView: String
    let action: AIAction
    let report: DiagnosticReport

    var summary: String {
        "Diagnostic report: \(report.certificates.count) certificates, \(report.recentSigningFailures.count) recent failures"
    }

    var payload: [String: Any] {
        [
            "certificateCount": report.certificates.count,
            "recentFailureCount": report.recentSigningFailures.count,
            "importedAppCount": report.importedApps.count,
            "sourceCount": report.sources.count,
            "anomalyCount": report.anomalies.count,
            "anomalies": report.anomalies
        ]
    }
}

struct DiagnosticReport: Codable {
    struct CertificateHealth: Codable {
        let name: String
        let status: String
        let daysUntilExpiry: Int
    }

    struct SigningFailure: Codable {
        let date: Date
        let appName: String
        let error: String
    }

    struct AppSummary: Codable {
        let name: String
        let bundleID: String
        let isEncrypted: Bool
        let isSigned: Bool
    }

    struct SourceStatus: Codable {
        let name: String
        let lastFetched: Date?
        let error: String?
    }

    let certificates: [CertificateHealth]
    let recentSigningFailures: [SigningFailure]
    let importedApps: [AppSummary]
    let sources: [SourceStatus]
    let anomalies: [String]
}

extension Date {
    fileprivate func ISO8601String() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate, .withTime, .withColonSeparatorInTime]
        return formatter.string(from: self)
    }
}
