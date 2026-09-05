import Foundation
import SwiftUI

// MARK: - FileItem

struct FileItem: Identifiable, Hashable, Codable {
    var id: String { url.path }
    let name: String
    let url: URL
    let size: Int64
    let creationDate: Date?
    let isDirectory: Bool
    
    var fileExtension: String? {
        return url.pathExtension.isEmpty ? nil : url.pathExtension
    }
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    // File type detection
    var isArchive: Bool {
        guard let ext = fileExtension?.lowercased() else { return false }
        return ["zip", "ipa", "deb", "tar", "gz", "rar", "7z"].contains(ext)
    }
    
    var isIPA: Bool {
        guard let ext = fileExtension?.lowercased() else { return false }
        return ext == "ipa"
    }
    
    var isP12Certificate: Bool {
        guard let ext = fileExtension?.lowercased() else { return false }
        return ext == "p12" || ext == "pfx"
    }
    
    var isMobileProvision: Bool {
        guard let ext = fileExtension?.lowercased() else { return false }
        return ext == "mobileprovision"
    }
    
    var isZipArchive: Bool {
        guard let ext = fileExtension?.lowercased() else { return false }
        return ["zip", "ipa"].contains(ext)
    }
    
    var isDebArchive: Bool {
        guard let ext = fileExtension?.lowercased() else { return false }
        return ext == "deb"
    }
    
    var isAppDirectory: Bool {
        return isDirectory && fileExtension?.lowercased() == "app"
    }
    
    var isFrameworkDirectory: Bool {
        return isDirectory && fileExtension?.lowercased() == "framework"
    }
    
    var isPlistFile: Bool {
        guard !isDirectory, let ext = fileExtension?.lowercased() else { return false }
        return ext == "plist"
    }
    
    var isEntitlementsFile: Bool {
        guard !isDirectory, let ext = fileExtension?.lowercased() else { return false }
        return ext == "entitlements"
    }
    
    var isDylibFile: Bool {
        guard !isDirectory, let ext = fileExtension?.lowercased() else { return false }
        return ["dylib", "so"].contains(ext)
    }
    
    var isLocalModelFile: Bool {
        guard !isDirectory, let ext = fileExtension?.lowercased() else { return false }
        return ["gguf", "mlx", "safetensors"].contains(ext)
    }
    
    var isImageFile: Bool {
        guard !isDirectory else { return false }
        let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "heic", "webp"]
        return imageExtensions.contains(fileExtension?.lowercased() ?? "")
    }
    
    var isTextFile: Bool {
        guard !isDirectory else { return false }
        let textExtensions: Set<String> = [
            "txt", "md", "json", "xml", "html", "css", "js", "ts", "swift", 
            "c", "cpp", "h", "m", "mm", "py", "rb", "sh", "yml", "yaml", 
            "plist", "entitlements", "log", "cfg", "conf", "ini"
        ]
        return textExtensions.contains(fileExtension?.lowercased() ?? "")
    }
    
    var isCodeFile: Bool {
        guard !isDirectory else { return false }
        let codeExtensions: Set<String> = ["swift", "m", "mm", "c", "cpp", "h", "hpp", "py", "js", "ts", "java", "kt"]
        return codeExtensions.contains(fileExtension?.lowercased() ?? "")
    }
    
    var fileTypeDisplayName: String {
        if isDirectory {
            if isAppDirectory { return "App Bundle" }
            if isFrameworkDirectory { return "Framework" }
            return "Folder"
        }
        if isLocalModelFile { return "Local Model" }
        let ext = fileExtension?.uppercased() ?? "FILE"
        return "\(ext) File"
    }
    
    var fileIcon: String {
        if isDirectory {
            if isAppDirectory { return "app.badge" }
            if isFrameworkDirectory { return "shippingbox" }
            return "folder"
        }
        if isIPA { return "app.badge" }
        if isArchive { return "doc.zipper" }
        if isP12Certificate { return "key.fill" }
        if isMobileProvision { return "doc.text.badge.plus" }
        if isPlistFile { return "list.bullet.rectangle" }
        if isEntitlementsFile { return "key.fill" }
        if isDylibFile { return "cube.box" }
        if isLocalModelFile { return "cpu" }
        if isImageFile { return "photo" }
        if isCodeFile { return "curlybraces" }
        if isTextFile { return "doc.text" }
        return "doc"
    }
    
    var fileIconColor: Color {
        if isDirectory {
            if isAppDirectory { return AppColors.success }
            if isFrameworkDirectory { return AppColors.warning }
            return AppColors.accent
        }
        if isIPA { return AppColors.success }
        if isArchive { return AppColors.accent }
        if isP12Certificate { return AppColors.warning }
        if isMobileProvision { return AppColors.info }
        if isPlistFile || isEntitlementsFile { return AppColors.accent }
        if isDylibFile { return ThemeManager.shared.accentColor }
        if isLocalModelFile { return AppColors.info }
        if isImageFile { return AppColors.secondaryText }
        if isCodeFile { return AppColors.info }
        return AppColors.secondaryText
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        return lhs.url == rhs.url
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case name, url, size, creationDate, isDirectory
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        let urlString = try container.decode(String.self, forKey: .url)
        url = URL(string: urlString)!
        size = try container.decode(Int64.self, forKey: .size)
        creationDate = try container.decodeIfPresent(Date.self, forKey: .creationDate)
        isDirectory = try container.decode(Bool.self, forKey: .isDirectory)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(url.absoluteString, forKey: .url)
        try container.encode(size, forKey: .size)
        try container.encode(creationDate, forKey: .creationDate)
        try container.encode(isDirectory, forKey: .isDirectory)
    }
    
    // MARK: - Initializers
    
    init(name: String, url: URL, size: Int64, creationDate: Date?, isDirectory: Bool) {
        self.name = name
        self.url = url
        self.size = size
        self.creationDate = creationDate
        self.isDirectory = isDirectory
    }
}

// MARK: - FileType Enum for Category Filtering

enum FileCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case ipas = "IPAs"
    case dylibs = "Dylibs"
    case certificates = "Certificates"
    case profiles = "Profiles"
    case plists = "Plists"
    case frameworks = "Frameworks"
    case archives = "Archives"
    case models = "Models"
    case images = "Images"
    case text = "Text"
    case folders = "Folders"
    case other = "Other"
    
    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .ipas: return "app.badge"
        case .dylibs: return "cube.box"
        case .certificates: return "checkmark.shield"
        case .profiles: return "doc.text.badge.plus"
        case .plists: return "list.bullet.rectangle"
        case .frameworks: return "shippingbox"
        case .archives: return "doc.zipper"
        case .models: return "cpu"
        case .images: return "photo"
        case .text: return "doc.text"
        case .folders: return "folder"
        case .other: return "doc"
        }
    }
    
    func matches(_ file: FileItem) -> Bool {
        switch self {
        case .all: return true
        case .ipas: return file.isIPA
        case .dylibs: return file.isDylibFile
        case .certificates: return file.isP12Certificate
        case .profiles: return file.isMobileProvision
        case .plists: return file.isPlistFile || file.isEntitlementsFile
        case .frameworks: return file.isFrameworkDirectory
        case .archives: return file.isArchive && !file.isIPA
        case .models: return file.isLocalModelFile
        case .images: return file.isImageFile
        case .text: return file.isTextFile
        case .folders: return file.isDirectory && !file.isAppDirectory && !file.isFrameworkDirectory
        case .other: return !file.isDirectory && !file.isIPA && !file.isDylibFile && !file.isP12Certificate && !file.isMobileProvision && !file.isPlistFile && !file.isEntitlementsFile && !file.isArchive && !file.isLocalModelFile && !file.isImageFile && !file.isTextFile && !file.isCodeFile
        }
    }
}