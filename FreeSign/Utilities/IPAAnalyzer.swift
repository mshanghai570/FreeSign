import Foundation
import UIKit

/// Extracts metadata from an IPA file without modifying it.
///
/// Implementation strategy:
///   1. Unzip the IPA into a temporary folder via BundleEditor/ZSignWrapper.
///   2. Read Info.plist, icon files, and the main Mach-O binary.
///   3. Clean up the temporary extraction.
///
/// This is intentionally kept synchronous so callers can wrap it in a Task.
final class IPAAnalyzer {

    static let shared = IPAAnalyzer()
    private init() {}

    // MARK: - Public API

    struct Result {
        let name: String
        let bundleID: String
        let version: String
        let buildNumber: String
        let minOSVersion: String
        let architectures: [String]
        let embeddedFrameworks: [String]
        let isEncrypted: Bool
        let isSigned: Bool
        let iconData: Data?          // raw PNG bytes of the best-resolution icon found
        let fileSize: Int64
    }

    /// Analyze an IPA at `ipaPath` (must be a path our sandbox can read directly).
    /// Throws on unrecoverable errors; partial results are NOT returned.
    func analyze(ipaPath: String) throws -> Result {
        let fileSize = StorageManager.shared.fileSize(at: ipaPath)

        // 1 — Extract to a temp directory inside our Extracts/ folder
        let extractDir = StorageManager.shared.newExtractDirectory()
        defer { StorageManager.shared.cleanupExtract(at: extractDir) }

        guard let extractedPath = try? ZSignWrapper.extractIPA(atPath: ipaPath) else {
            throw AnalyzerError.extractionFailed
        }

        // 2 — Find the .app bundle
        let payloadPath = (extractedPath as NSString).appendingPathComponent("Payload")
        let payloadContents = try FileManager.default.contentsOfDirectory(atPath: payloadPath)
        guard let appFolder = payloadContents.first(where: { $0.hasSuffix(".app") }) else {
            throw AnalyzerError.noAppBundle
        }
        let appFolderPath = (payloadPath as NSString).appendingPathComponent(appFolder)

        // 3 — Parse Info.plist
        let infoPlistPath = (appFolderPath as NSString).appendingPathComponent("Info.plist")
        guard let infoDict = NSDictionary(contentsOfFile: infoPlistPath) as? [String: Any] else {
            throw AnalyzerError.noInfoPlist
        }

        let name = (infoDict["CFBundleDisplayName"] as? String)
                ?? (infoDict["CFBundleName"] as? String)
                ?? appFolder.replacingOccurrences(of: ".app", with: "")
        let bundleID     = infoDict["CFBundleIdentifier"] as? String ?? "unknown"
        let version      = infoDict["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber  = infoDict["CFBundleVersion"] as? String ?? "1"
        let minOS        = infoDict["MinimumOSVersion"] as? String ?? "12.0"

        // 4 — Architectures (parse Mach-O headers)
        let execName     = infoDict["CFBundleExecutable"] as? String ?? name
        let execPath     = (appFolderPath as NSString).appendingPathComponent(execName)
        let archs        = detectArchitectures(executablePath: execPath)

        // 5 — Embedded frameworks
        let fwPath   = (appFolderPath as NSString).appendingPathComponent("Frameworks")
        let fwItems  = (try? FileManager.default.contentsOfDirectory(atPath: fwPath)) ?? []
        let frameworks = fwItems.filter { $0.hasSuffix(".framework") || $0.hasSuffix(".dylib") }

        // 6 — Encryption & signature flags via the Mach-O LC_ENCRYPTION_INFO load command
        let (isEncrypted, isSigned) = detectEncryptionAndSignature(executablePath: execPath)

        // 7 — Icon extraction
        let iconData = extractBestIcon(appFolderPath: appFolderPath, infoDict: infoDict)

        return Result(
            name:               name,
            bundleID:           bundleID,
            version:            version,
            buildNumber:        buildNumber,
            minOSVersion:       minOS,
            architectures:      archs,
            embeddedFrameworks: frameworks,
            isEncrypted:        isEncrypted,
            isSigned:           isSigned,
            iconData:           iconData,
            fileSize:           fileSize
        )
    }

    // MARK: - Architecture Detection

    private func detectArchitectures(executablePath: String) -> [String] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: executablePath),
                                   options: .mappedIfSafe),
              data.count >= 8 else {
            return ["arm64"]
        }
        return parseMachO(data: data)
    }

    private func parseMachO(data: Data) -> [String] {
        let bytes = data.withUnsafeBytes { $0 }
        let magic = bytes.load(as: UInt32.self)

        switch magic {
        case 0xCAFEBABE, 0xBEBAFECA:
            // Fat binary — always big-endian fat header
            return parseFatBinary(data: data)

        case 0xFEEDFACF: // 64-bit little-endian
            let cpu = bytes.load(fromByteOffset: 4, as: UInt32.self)
            return [cpuName(type: cpu, bigEndian: false)]

        case 0xCFFAEDFE: // 64-bit big-endian (arm64 on old firmwares, rare)
            let cpu = bytes.load(fromByteOffset: 4, as: UInt32.self)
            return [cpuName(type: cpu, bigEndian: true)]

        case 0xFEEDFACE, 0xCEFAEDFE: // 32-bit
            return ["armv7"]

        default:
            return ["arm64"]
        }
    }

    private func parseFatBinary(data: Data) -> [String] {
        // Fat header is always big-endian
        // struct fat_header { uint32_t magic; uint32_t nfat_arch; }
        // struct fat_arch   { cpu_type_t cputype; cpu_subtype_t cpusubtype; ... } (20 bytes each)
        guard data.count >= 8 else { return [] }
        let bytes = data.withUnsafeBytes { $0 }

        let nArch = bytes.load(fromByteOffset: 4, as: UInt32.self).bigEndian
        var result: [String] = []

        for i in 0..<Int(nArch) {
            let offset = 8 + i * 20
            guard offset + 8 <= data.count else { break }
            let cpuType = bytes.load(fromByteOffset: offset, as: UInt32.self).bigEndian
            result.append(cpuName(type: cpuType, bigEndian: true))
        }

        return result.isEmpty ? ["arm64"] : result
    }

    private func cpuName(type cpuType: UInt32, bigEndian: Bool) -> String {
        let t = bigEndian ? cpuType : cpuType.byteSwapped
        switch t {
        case 0x0000000C:       return "armv7"
        case 0x0100000C:       return "arm64"
        case 0x0200000C:       return "arm64_32"
        case 0x0100000C | 2:   return "arm64e"
        default:               return String(format: "cpu_0x%X", t)
        }
    }

    // MARK: - Encryption / Signature Detection

    private func detectEncryptionAndSignature(executablePath: String) -> (encrypted: Bool, signed: Bool) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: executablePath),
                                   options: .mappedIfSafe),
              data.count >= 16 else {
            return (false, false)
        }

        let bytes = data.withUnsafeBytes { $0 }
        let magic = bytes.load(as: UInt32.self)

        // Determine header size
        let is64 = (magic == 0xFEEDFACF || magic == 0xCFFAEDFE)
        let headerSize = is64 ? 32 : 28
        let isBE = (magic == 0xCFFAEDFE || magic == 0xFEEDFACF)

        guard data.count > headerSize else { return (false, false) }

        func readUInt32(at offset: Int) -> UInt32 {
            let v = bytes.load(fromByteOffset: offset, as: UInt32.self)
            return isBE ? v.bigEndian : v
        }

        let ncmds = readUInt32(at: is64 ? 16 : 12)
        var offset = headerSize
        var encrypted = false
        var hasSig    = false

        for _ in 0..<ncmds {
            guard offset + 8 <= data.count else { break }
            let cmd  = readUInt32(at: offset)
            let size = readUInt32(at: offset + 4)

            switch cmd {
            case 0x21:       // LC_ENCRYPTION_INFO
                let cryptID = readUInt32(at: offset + 12)
                if cryptID != 0 { encrypted = true }
            case 0x2C:       // LC_ENCRYPTION_INFO_64
                let cryptID = readUInt32(at: offset + 16)
                if cryptID != 0 { encrypted = true }
            case 0x1D:       // LC_CODE_SIGNATURE
                hasSig = true
            default:
                break
            }

            let advance = Int(size)
            if advance < 8 { break }
            offset += advance
        }

        return (encrypted, hasSig)
    }

    // MARK: - Icon Extraction

    private func extractBestIcon(appFolderPath: String, infoDict: [String: Any]) -> Data? {
        let candidates = collectIconNames(from: infoDict)

        // Try to find the largest icon by looking for 60@3x, 60@2x, 76@2x, etc.
        let sizePriority = ["60@3x", "60@2x", "76@2x", "76@1x", "60@1x", "icon"]

        for hint in sizePriority {
            for name in candidates {
                if name.lowercased().contains(hint.lowercased().replacingOccurrences(of: "@", with: "")) {
                    if let data = iconData(name: name, folder: appFolderPath) { return data }
                }
            }
        }

        // Fallback: just pick the first candidate that resolves
        for name in candidates {
            if let data = iconData(name: name, folder: appFolderPath) { return data }
        }

        // Last resort: scan for any PNG that looks like an icon
        return scanForAnyIcon(in: appFolderPath)
    }

    private func collectIconNames(from info: [String: Any]) -> [String] {
        var names: [String] = []

        func addFromPrimaryIcon(_ dict: [String: Any]) {
            if let primary = dict["CFBundlePrimaryIcon"] as? [String: Any] {
                if let files = primary["CFBundleIconFiles"] as? [String] { names += files }
                if let n     = primary["CFBundleIconName"]  as? String   { names.append(n) }
            }
        }

        if let icons = info["CFBundleIcons"] as? [String: Any]      { addFromPrimaryIcon(icons) }
        if let icons = info["CFBundleIcons~ipad"] as? [String: Any] { addFromPrimaryIcon(icons) }
        if let legacy = info["CFBundleIconFile"]  as? String         { names.append(legacy) }
        if let legacy = info["CFBundleIconFiles"] as? [String]       { names += legacy }

        return names
    }

    private func iconData(name: String, folder: String) -> Data? {
        let fm = FileManager.default
        let variants = [
            name,
            "\(name).png",
            "\(name)@3x.png",
            "\(name)@2x.png",
            "\(name)~ipad.png",
            "\(name)@2x~ipad.png"
        ]
        for v in variants {
            let path = (folder as NSString).appendingPathComponent(v)
            if fm.fileExists(atPath: path),
               let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                return normalizeIcon(data: data)
            }
        }
        return nil
    }

    private func scanForAnyIcon(in folder: String) -> Data? {
        guard let enumerator = FileManager.default.enumerator(atPath: folder) else { return nil }
        while let file = enumerator.nextObject() as? String {
            let lower = file.lowercased()
            if lower.hasSuffix(".png") && lower.contains("icon") {
                let path = (folder as NSString).appendingPathComponent(file)
                if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                    return normalizeIcon(data: data)
                }
            }
        }
        return nil
    }

    /// iOS app icons may have non-standard color spaces. Normalise to sRGB PNG.
    private func normalizeIcon(data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return data }
        // Re-render at a consistent size so all icons look uniform in the UI
        let size = CGSize(width: 120, height: 120)
        let renderer = UIGraphicsImageRenderer(size: size)
        let rendered = renderer.image { ctx in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.pngData() ?? data
    }
}

// MARK: - Errors

enum AnalyzerError: LocalizedError {
    case extractionFailed
    case noAppBundle
    case noInfoPlist

    var errorDescription: String? {
        switch self {
        case .extractionFailed: return "Failed to extract IPA archive."
        case .noAppBundle:      return "No .app bundle found inside IPA Payload."
        case .noInfoPlist:      return "App bundle is missing Info.plist."
        }
    }
}
