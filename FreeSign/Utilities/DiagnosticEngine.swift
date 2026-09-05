import Foundation

enum DiagnosticEngine {
    static func generateReport() -> DiagnosticReport {
        let dataManager = AppDataManager.shared
        let signingManager = SigningManager.shared

        let certificates = dataManager.certificates.map { cert in
            DiagnosticReport.CertificateHealth(
                name: cert.name,
                status: certStatus(for: cert),
                daysUntilExpiry: cert.daysUntilExpiry
            )
        }

        let importedApps = dataManager.importedApps.map { app in
            DiagnosticReport.AppSummary(
                name: app.name,
                bundleID: app.bundleID,
                isEncrypted: app.isEncrypted,
                isSigned: app.isSigned
            )
        }

        let sources = dataManager.sources.map { source in
            DiagnosticReport.SourceStatus(
                name: source.name,
                lastFetched: source.lastFetched,
                error: nil
            )
        }

        let recentFailures: [DiagnosticReport.SigningFailure] = []
        let anomalies = detectAnomalies(in: dataManager, signingManager: signingManager)

        return DiagnosticReport(
            certificates: certificates,
            recentSigningFailures: recentFailures,
            importedApps: importedApps,
            sources: sources,
            anomalies: anomalies
        )
    }

    static func diagnosticContext() -> DiagnosticContext {
        let report = generateReport()
        return DiagnosticContext(
            sourceView: "DiagnosticEngine",
            action: .analyze,
            report: report
        )
    }

    private static func certStatus(for cert: Certificate) -> String {
        if cert.isExpired { return "expired" }
        if cert.daysUntilExpiry < 14 { return "expiring_soon" }
        if cert.provisioningProfiles.isEmpty { return "no_profile" }
        return "healthy"
    }

    private static func detectAnomalies(
        in dataManager: AppDataManager,
        signingManager: SigningManager
    ) -> [String] {
        var anomalies: [String] = []

        if dataManager.certificates.isEmpty {
            anomalies.append("No certificates imported.")
        }

        for cert in dataManager.certificates where cert.isExpired {
            anomalies.append("Certificate '\(cert.name)' is expired.")
        }

        for cert in dataManager.certificates where !cert.isExpired && cert.daysUntilExpiry < 14 {
            anomalies.append("Certificate '\(cert.name)' expires in \(cert.daysUntilExpiry) days.")
        }

        for cert in dataManager.certificates where cert.provisioningProfiles.isEmpty {
            anomalies.append("Certificate '\(cert.name)' has no provisioning profile attached.")
        }

        for app in dataManager.importedApps where app.isEncrypted {
            anomalies.append("Imported app '\(app.name)' is FairPlay-encrypted.")
        }

        if !signingManager.statusMessage.isEmpty,
           signingManager.statusMessage.lowercased().contains("failed") {
            anomalies.append("Recent signing failure: \(signingManager.statusMessage)")
        }

        return anomalies
    }
}
