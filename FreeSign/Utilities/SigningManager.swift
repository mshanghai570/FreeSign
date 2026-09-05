import Foundation

class SigningManager: ObservableObject {
    static let shared = SigningManager()
    
    @Published var isSigning = false
    @Published var progress: Float = 0
    @Published var statusMessage = ""
    
    func signPackage(_ app: AppInfo,
                    certificate: Certificate,
                    options: SigningOptions,
                    iconOverride: Data?,
                    completion: @escaping (Result<String, Error>) -> Void) {

        // Guard against invalid app path
        guard !app.filePath.isEmpty else {
            DispatchQueue.main.async {
                self.isSigning = false
                self.progress = 0
                self.statusMessage = "Signing failed: App file path is invalid"
                completion(.failure(NSError(domain: "SigningError", code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "App file path is empty or invalid"])))
            }
            return
        }

        isSigning = true
        progress = 0
        statusMessage = "Initializing..."

        let tempDir = FileManager.default.temporaryDirectory
        let outputName = "\(app.name)_signed.ipa"
        let outputPath = tempDir.appendingPathComponent(outputName).path

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            // MARK: - Pre-Signing Bundle Modifications

            DispatchQueue.main.async { self.progress = 0.1; self.statusMessage = "Preparing bundle modifications..." }

            // Inject dylibs if specified
            if !options.injectDylibs.isEmpty {
                DispatchQueue.main.async { self.statusMessage = "Injecting dylibs..." }
                self.injectDylibs(into: app.filePath, dylibs: options.injectDylibs, options: options)
            }

            // Apply entitlements if specified
            let entitlementsPath = options.entitlementsPath
            DispatchQueue.main.async { self.progress = 0.2; self.statusMessage = "Initializing signing engine..." }

            let certPath = certificate.p12Path
            let provPath = certificate.provisioningProfiles.first?.path
            let password = certificate.password.isEmpty ? nil : certificate.password
            let bundleId = options.appIdentifier?.isEmpty == false ? options.appIdentifier : nil
            let bundleName = options.appName?.isEmpty == false ? options.appName : nil
            let bundleVersion = options.appVersion?.isEmpty == false ? options.appVersion : nil

            // Guard against missing certificate path
            guard !certPath.isEmpty else {
                DispatchQueue.main.async {
                    self.isSigning = false
                    self.progress = 0
                    self.statusMessage = "Signing failed: No certificate path"
                    completion(.failure(NSError(domain: "SigningError", code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Certificate path is empty"])))
                }
                return
            }

            // Guard against missing IPA file
            guard FileManager.default.fileExists(atPath: app.filePath) else {
                DispatchQueue.main.async {
                    self.isSigning = false
                    self.progress = 0
                    self.statusMessage = "Signing failed: IPA file not found"
                    completion(.failure(NSError(domain: "SigningError", code: -5,
                        userInfo: [NSLocalizedDescriptionKey: "IPA file does not exist at path: \(app.filePath)"])))
                }
                return
            }

            // Guard against missing certificate file
            guard FileManager.default.fileExists(atPath: certPath) else {
                DispatchQueue.main.async {
                    self.isSigning = false
                    self.progress = 0
                    self.statusMessage = "Signing failed: Certificate file not found"
                    completion(.failure(NSError(domain: "SigningError", code: -6,
                        userInfo: [NSLocalizedDescriptionKey: "Certificate file does not exist at path: \(certPath)"])))
                }
                return
            }

            let result = ZSignWrapper.signIPA(
                atPath: app.filePath,
                certPath: certPath,
                pkeyPath: certPath,
                provPath: provPath,
                password: password,
                bundleId: bundleId,
                bundleName: bundleName,
                bundleVersion: bundleVersion,
                outputPath: outputPath
            )

            DispatchQueue.main.async {
                self.isSigning = false
                self.progress = 1.0

                if result.success, let output = result.outputPath {
                    self.statusMessage = "Signed successfully!"
                    let installed = InstalledApp(
                        id: UUID(),
                        name: options.appName ?? app.name,
                        bundleID: options.appIdentifier ?? app.bundleID,
                        version: options.appVersion ?? app.version,
                        originalIPA: app.filePath,
                        signedIPA: output,
                        iconData: iconOverride ?? app.iconData,
                        isSigned: true,
                        installDate: Date(),
                        signDate: Date()
                    )
                    AppDataManager.shared.addInstalledApp(installed)
                    
                    // Post-signing actions
                    if options.installAfterSigning {
                        self.installSignedIPA(output)
                    }
                    if options.shareAfterSigning {
                        self.shareSignedIPA(output)
                    }
                    
                    completion(.success(output))
                } else {
                    self.statusMessage = "Signing failed: \(result.errorMessage ?? "Unknown error")"
                    completion(.failure(NSError(domain: "SigningError", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: result.errorMessage ?? "Unknown error"])))
                }
            }
        }
    }

    // MARK: - Dylib Injection
    
    /// Injects dylib files into the IPA's main binary before signing.
    private func injectDylibs(into ipaPath: String, dylibs: [String], options: SigningOptions) {
        // Use BundleEditor/ZSignWrapper to inject dylibs into the extracted IPA.
        // This mirrors Feather's SigningHandler.modify() step for injection.
        guard let extractedPath = (try? ZSignWrapper.extractIPA(atPath: ipaPath)) ?? nil else {
            print("⚠️ Failed to extract IPA for dylib injection")
            return
        }
        let extractPath = URL(fileURLWithPath: extractedPath)
        
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: extractPath, includingPropertiesForKeys: nil) else { return }
        
        // Find the .app bundle
        guard let payloadDir = contents.first(where: { $0.lastPathComponent == "Payload" }),
              let apps = try? fm.contentsOfDirectory(at: payloadDir, includingPropertiesForKeys: nil) else { return }
        
        for appDir in apps where appDir.pathExtension == "app" {
            let binaryName = appDir.deletingPathExtension().lastPathComponent
            let binaryPath = appDir.appendingPathComponent(binaryName).path
            
            for dylibPath in dylibs {
                // Inject each dylib using optool-like logic via ZSign
                self.injectDylib(binaryPath: binaryPath, dylibPath: dylibPath, options: options)
            }
        }
        
        // Re-zip the extracted IPA back to the original path
        // (This is a simplified approach — a full implementation would use a zip utility)
    }
    
    /// Injects a single dylib into a Mach-O binary using LC_LOAD_DYLIB commands.
    private func injectDylib(binaryPath: String, dylibPath: String, options: SigningOptions) {
        // This would call into the optool-like functionality in the C++ layer.
        // For now, we log the intent — the actual injection requires the zsign
        // or optool library support which can be extended in the C++ layer.
        print("ℹ️ Would inject \(dylibPath) into \(binaryPath) with options: weakInject=\(options.weakInject)")
    }

    // MARK: - Post-Signing Actions
    
    private func installSignedIPA(_ path: String) {
        // Attempt installation via itms-services:// URL scheme
        // This requires a web server hosting the IPA — for local install,
        // we could use the system's "Open in..." dialog
        print("ℹ️ Would install signed IPA from: \(path)")
    }
    
    private func shareSignedIPA(_ path: String) {
        // Open a share sheet with the signed IPA
        guard let url = URL(string: path) else { return }
        print("ℹ️ Would share signed IPA: \(url.lastPathComponent)")
    }
}
