import Foundation

// MARK: - Swift Extensions for ZSignWrapper

extension ZSignWrapper {
    
    /// Get certificate information from a P12 file (Swift-friendly version)
    /// - Parameters:
    ///   - p12Path: Path to the .p12 file
    ///   - password: Password for the P12 file (optional)
    /// - Returns: Dictionary with certificate info or nil on failure
    /// - Throws: NSError if the operation fails
    static func certificateInfo(fromP12 p12Path: String, password: String?) throws -> [AnyHashable: Any]? {
        var error: NSError?
        let result = certificateInfoFromP12(p12Path, password: password, error: &error)
        
        if let error = error {
            throw error
        }
        
        return result as? [AnyHashable: Any]
    }
    
/// Sign an IPA file with simplified parameters
    /// - Parameters:
    ///   - ipaPath: Path to the input IPA
    ///   - p12Path: Path to the P12 certificate
    ///   - password: Password for the P12 file
    ///   - provPath: Path to the provisioning profile
    ///   - bundleId: Optional bundle ID override
    ///   - outputPath: Optional output path
    /// - Returns: ZSignResult with success/failure info
    static func signIPA(ipaPath: String, 
                      p12Path: String, 
                      password: String?, 
                      provPath: String?, 
                      bundleId: String? = nil,
                      outputPath: String? = nil) -> ZSignResult {
        return signIPAAtPath(ipaPath, 
                         certPath: nil, 
                         pkeyPath: p12Path, 
                         provPath: provPath, 
                         password: password, 
                         bundleId: bundleId, 
                         bundleName: nil, 
                         bundleVersion: nil, 
                         outputPath: outputPath)
    }
}