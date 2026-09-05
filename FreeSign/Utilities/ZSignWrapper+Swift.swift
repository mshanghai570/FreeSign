import Foundation

// MARK: - Swift Extensions for ZSignWrapper

extension ZSignWrapper {
    /// Reads certificate information from a P12/PFX file.
    ///
    /// The Objective-C bridge uses an NSError out-parameter. Convert both an
    /// explicit bridge error and an unexpected nil result into Swift errors so
    /// callers never silently continue with an invalid identity.
    static func certificateInfo(fromP12 p12Path: String, password: String?) throws -> [AnyHashable: Any] {
        let result = try certificateInfoFromP12(p12Path, password: password)
        guard let dictionary = result as? [AnyHashable: Any] else {
            throw NSError(
                domain: "com.freesign.zsign",
                code: -100,
                userInfo: [NSLocalizedDescriptionKey: "The certificate could not be read."]
            )
        }
        return dictionary
    }

    /// Signs an IPA with simplified parameters.
    static func signIPA(
        ipaPath: String,
        p12Path: String,
        password: String?,
        provPath: String?,
        bundleId: String? = nil,
        outputPath: String? = nil
    ) -> ZSignResult {
        signIPA(
            ipaPath,
            certPath: nil,
            pkeyPath: p12Path,
            provPath: provPath,
            password: password,
            bundleId: bundleId,
            bundleName: nil,
            bundleVersion: nil,
            outputPath: outputPath
        )
    }

    /// Signs an IPA while applying the supported `SigningOptions` directly in
    /// the native ZSign bundle operation. This keeps the UI options and the
    /// produced archive in sync rather than signing the original IPA after a
    /// separate, temporary modification attempt.
    static func signIPAWithOptions(
        ipaPath: String,
        certificatePath: String?,
        provisioningProfilePath: String?,
        entitlementsPath: String?,
        password: String?,
        options: SigningOptions,
        outputPath: String,
        iconPath: String? = nil
    ) -> ZSignResult {
        signIPAWithOptions(
            atPath: ipaPath,
            certPath: certificatePath,
            pkeyPath: certificatePath,
            provPath: provisioningProfilePath,
            entitlementsPath: entitlementsPath,
            password: password,
            bundleId: options.appIdentifier?.nonEmpty,
            bundleName: options.appName?.nonEmpty,
            bundleVersion: options.appVersion?.nonEmpty,
            outputPath: outputPath,
            dylibPaths: options.injectDylibs,
            removeDylibNames: options.removeDylibs,
            forceSign: options.forceResign,
            weakInject: options.weakInject,
            removeExtensions: options.removeExtensions,
            removeWatchApp: options.removeWatchApp,
            removeUISupportedDevices: options.removeUISupportedDevices,
            enableDocuments: options.enableDocuments,
            minOSVersion: options.minOSVersion?.nonEmpty,
            iconPath: iconPath,
            adHoc: options.isAdhoc
        )
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
