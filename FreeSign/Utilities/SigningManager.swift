import Foundation

/// Coordinates a signing job and persists the finished IPA in the app's shared
/// Documents/Signed directory. Native ZSign work is always kept off the main
/// actor; UI state and data-store updates return to the main queue.
final class SigningManager: ObservableObject {
    static let shared = SigningManager()

    @Published var isSigning = false
    @Published var progress: Float = 0
    @Published var statusMessage = ""

    func signPackage(
        _ app: AppInfo,
        certificate: Certificate?,
        options: SigningOptions,
        iconOverride: Data?,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard !app.filePath.isEmpty,
              FileManager.default.fileExists(atPath: app.filePath) else {
            completeFailure(
                message: "Signing failed: IPA file not found",
                error: SigningError.ipaNotFound,
                completion: completion
            )
            return
        }

        if !options.isAdhoc {
            guard let certificate else {
                completeFailure(
                    message: "Signing failed: Select a certificate or enable Ad-Hoc Signing.",
                    error: SigningError.certificateRequired,
                    completion: completion
                )
                return
            }
            guard !certificate.isExpired else {
                completeFailure(
                    message: "Signing failed: The selected certificate has expired.",
                    error: SigningError.certificateExpired,
                    completion: completion
                )
                return
            }
            guard FileManager.default.fileExists(atPath: certificate.p12Path) else {
                completeFailure(
                    message: "Signing failed: Certificate file not found",
                    error: SigningError.certificateNotFound,
                    completion: completion
                )
                return
            }
            guard let profile = certificate.provisioningProfiles.first,
                  FileManager.default.fileExists(atPath: profile.path) else {
                completeFailure(
                    message: "Signing failed: Attach a valid provisioning profile to the selected certificate.",
                    error: SigningError.provisioningProfileRequired,
                    completion: completion
                )
                return
            }
            guard !profile.isExpired else {
                completeFailure(
                    message: "Signing failed: The attached provisioning profile has expired.",
                    error: SigningError.provisioningProfileExpired,
                    completion: completion
                )
                return
            }
            let requestedBundleID = options.appIdentifier?.nonEmpty ?? app.bundleID
            guard profile.matches(bundleID: requestedBundleID) else {
                completeFailure(
                    message: "Signing failed: The selected provisioning profile does not cover \(requestedBundleID).",
                    error: SigningError.incompatibleProvisioningProfile,
                    completion: completion
                )
                return
            }
        }

        if let path = options.entitlementsPath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty,
           !FileManager.default.fileExists(atPath: path) {
            completeFailure(
                message: "Signing failed: Custom entitlements file not found",
                error: SigningError.entitlementsNotFound,
                completion: completion
            )
            return
        }

        isSigning = true
        progress = 0
        statusMessage = "Preparing signing job…"

        let safeName = sanitizedFileName(options.appName?.nonEmpty ?? app.name)
        let outputURL = StorageManager.shared.signedURL
            .appendingPathComponent("\(safeName)_\(UUID().uuidString.prefix(8)).ipa")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            do {
                try FileManager.default.createDirectory(
                    at: StorageManager.shared.signedURL,
                    withIntermediateDirectories: true
                )
                try? FileManager.default.removeItem(at: outputURL)

                DispatchQueue.main.async {
                    self.progress = 0.15
                    self.statusMessage = "Preparing bundle options…"
                }

                let iconURL = try self.writeTemporaryIcon(iconOverride)
                defer {
                    if let iconURL {
                        try? FileManager.default.removeItem(at: iconURL)
                    }
                }

                let certificatePath: String?
                let profilePath: String?
                let password: String?
                if options.isAdhoc {
                    certificatePath = nil
                    profilePath = nil
                    password = nil
                } else if let certificate {
                    certificatePath = certificate.p12Path
                    profilePath = certificate.provisioningProfiles.first?.path
                    password = KeychainHelper.loadCertificatePasswordSync(certificateID: certificate.id)
                        ?? certificate.password.nonEmpty
                } else {
                    throw SigningError.certificateRequired
                }

                DispatchQueue.main.async {
                    self.progress = 0.35
                    self.statusMessage = "Signing IPA…"
                }

                let result = ZSignWrapper.signIPAWithOptions(
                    ipaPath: app.filePath,
                    certificatePath: certificatePath,
                    provisioningProfilePath: profilePath,
                    entitlementsPath: options.entitlementsPath?.nonEmpty,
                    password: password,
                    options: options,
                    outputPath: outputURL.path,
                    iconPath: iconURL?.path
                )

                guard result.success,
                      let signedPath = result.outputPath,
                      FileManager.default.fileExists(atPath: signedPath) else {
                    try? FileManager.default.removeItem(at: outputURL)
                    throw SigningError.nativeFailure(result.errorMessage ?? "The signing engine did not create an IPA.")
                }

                DispatchQueue.main.async {
                    self.isSigning = false
                    self.progress = 1.0
                    self.statusMessage = "Signed IPA saved to Documents/Signed."

                    let installed = InstalledApp(
                        id: UUID(),
                        name: options.appName?.nonEmpty ?? app.name,
                        bundleID: options.appIdentifier?.nonEmpty ?? app.bundleID,
                        version: options.appVersion?.nonEmpty ?? app.version,
                        originalIPA: app.filePath,
                        signedIPA: signedPath,
                        iconData: iconOverride ?? app.iconData,
                        isSigned: true,
                        installDate: Date(),
                        signDate: Date()
                    )
                    AppDataManager.shared.addInstalledApp(installed)

                    var updatedApp = app
                    updatedApp.lastSignedWith = options.isAdhoc ? "Ad-Hoc" : certificate?.name
                    updatedApp.lastSignedDate = Date()
                    AppDataManager.shared.updateImportedApp(updatedApp)
                    completion(.success(signedPath))
                }
            } catch {
                self.completeFailure(
                    message: "Signing failed: \(error.localizedDescription)",
                    error: error,
                    completion: completion
                )
            }
        }
    }

    private func writeTemporaryIcon(_ iconData: Data?) throws -> URL? {
        guard let iconData, !iconData.isEmpty else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("freesign-icon-\(UUID().uuidString).png")
        try iconData.write(to: url, options: .atomic)
        return url
    }

    private func completeFailure(
        message: String,
        error: Error,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        DispatchQueue.main.async {
            self.isSigning = false
            self.progress = 0
            self.statusMessage = message
            completion(.failure(error))
        }
    }

    private func sanitizedFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\")
        let clean = name.components(separatedBy: invalid).joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "SignedApp" : clean
    }
}

private enum SigningError: LocalizedError {
    case ipaNotFound
    case certificateRequired
    case certificateNotFound
    case certificateExpired
    case provisioningProfileRequired
    case provisioningProfileExpired
    case incompatibleProvisioningProfile
    case entitlementsNotFound
    case nativeFailure(String)

    var errorDescription: String? {
        switch self {
        case .ipaNotFound:
            return "The source IPA is missing from FreeSign storage."
        case .certificateRequired:
            return "Select a signing certificate or enable Ad-Hoc Signing."
        case .certificateNotFound:
            return "The selected certificate file is no longer available."
        case .certificateExpired:
            return "The selected certificate has expired."
        case .provisioningProfileRequired:
            return "Attach a provisioning profile to the selected certificate."
        case .provisioningProfileExpired:
            return "The attached provisioning profile has expired."
        case .incompatibleProvisioningProfile:
            return "The selected provisioning profile does not cover this bundle identifier."
        case .entitlementsNotFound:
            return "The selected custom entitlements file is no longer available."
        case .nativeFailure(let message):
            return message
        }
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension ProvisioningProfile {
    func matches(bundleID: String) -> Bool {
        let profileID = self.bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        if profileID == "*" || profileID.isEmpty { return true }
        if profileID == bundleID { return true }
        guard profileID.hasSuffix(".*") else { return false }
        let prefix = String(profileID.dropLast())
        return bundleID.hasPrefix(prefix)
    }
}
