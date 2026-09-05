import Foundation

// MARK: - Swift Extensions for ZSignWrapper

extension ZSignWrapper {
    /// Reads certificate information from a P12/PFX file.
    ///
    /// The Objective-C bridge uses an NSError out-parameter. Convert both an
    /// explicit bridge error and an unexpected nil result into Swift errors so
    /// callers never silently continue with an invalid identity.
    static func certificateInfo(fromP12 p12Path: String, password: String?) throws -> [AnyHashable: Any] {
        var error: NSError?
        let result = certificateInfoFromP12(p12Path, password: password, error: &error)

        if let error { throw error }
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
        signIPAAtPath(
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
}
