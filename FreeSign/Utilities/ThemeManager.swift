import SwiftUI
import Combine

// MARK: - Theme Preset

enum ThemePreset: String, Codable, CaseIterable, Identifiable {

    case bronzeVault
    case midnight
    case forest
    case crimson
    case ocean
    case sakura
    case monochrome
    case sunset
    case custom

    var displayName: String {
        switch self {
        case .bronzeVault: return "Bronze Vault"
        case .midnight:    return "Midnight"
        case .forest:      return "Forest"
        case .crimson:     return "Crimson"
        case .ocean:       return "Ocean"
        case .sakura:      return "Sakura"
        case .monochrome:  return "Monochrome"
        case .sunset:      return "Sunset"
        case .custom:      return "Custom"
        }
    }

    var accentHex: String {
        switch self {
        case .bronzeVault: return "#B87333"
        case .midnight:    return "#6366F1"
        case .forest:      return "#22C55E"
        case .crimson:     return "#EF4444"
        case .ocean:       return "#0EA5E9"
        case .sakura:      return "#EC4899"
        case .monochrome:  return "#9CA3AF"
        case .sunset:      return "#F97316"
        case .custom:      return "#B87333" // Default for custom
        }
    }

    var bgHex: String {
        switch self {
        case .bronzeVault: return "#0D0D10"
        case .midnight:    return "#080810"
        case .forest:      return "#080F08"
        case .crimson:     return "#100808"
        case .ocean:       return "#060D14"
        case .sakura:      return "#100A14"
        case .monochrome:  return "#0D0D0D"
        case .sunset:      return "#100C08"
        case .custom:      return "#0D0D10"
        }
    }

    var surfaceHex: String {
        switch self {
        case .bronzeVault: return "#16161B"
        case .midnight:    return "#12121E"
        case .forest:      return "#111A11"
        case .crimson:     return "#1C1010"
        case .ocean:       return "#0E1A26"
        case .sakura:      return "#1C1222"
        case .monochrome:  return "#1A1A1A"
        case .sunset:      return "#1C1410"
        case .custom:      return "#16161B"
        }
    }

    // Swatch color shown in the preset picker
    var swatchColor: Color { Color(hex: accentHex) }
}

// MARK: - Card Style

enum ThemeCardStyle: String, Codable, CaseIterable, Identifiable {
    case outlined = "Outlined"
    case glass    = "Glass"
    
    var displayName: String {
        switch self {
        case .outlined: return "Outlined"
        case .glass: return "Glass"
        }
    }
}

// MARK: - App Icon Style (Feather feature)

enum AppIconStyle: String, Codable, CaseIterable, Identifiable {
    
    case system = "System"
    case rounded = "Rounded"
    case squared = "Squared"
    
    var displayName: String {
        switch self {
        case .system: return "System Default"
        case .rounded: return "Rounded Corners"
        case .squared: return "Sharp Corners"
        }
    }
}

// MARK: - Signing Options (ZSign features)

enum SigningBehavior: String, Codable, CaseIterable, Identifiable {
    
    case ask = "Ask"
    case auto = "Auto-Sign"
    case manual = "Manual Only"
    
    var displayName: String {
        switch self {
        case .ask: return "Ask Before Signing"
        case .auto: return "Auto-Sign All"
        case .manual: return "Manual Signing Only"
        }
    }
}

enum CertificateValidation: String, Codable, CaseIterable, Identifiable {
    
    case strict = "Strict"
    case lenient = "Lenient"
    case none = "None"
    
    var displayName: String {
        switch self {
        case .strict: return "Strict Validation"
        case .lenient: return "Lenient Validation"
        case .none: return "No Validation"
        }
    }
}

// MARK: - Repository Options (Feather feature)

enum RepositoryBehavior: String, Codable, CaseIterable, Identifiable {
    
    case autoRefresh = "Auto-Refresh"
    case manualRefresh = "Manual Refresh"
    case neverRefresh = "Never Refresh"
    
    var displayName: String {
        switch self {
        case .autoRefresh: return "Auto-Refresh Repositories"
        case .manualRefresh: return "Manual Refresh Only"
        case .neverRefresh: return "Never Refresh"
        }
    }
}

enum AppSorting: String, Codable, CaseIterable, Identifiable {
    
    case name = "Name"
    case date = "Date Imported"
    case size = "File Size"
    case bundleID = "Bundle ID"
    
    var displayName: String {
        switch self {
        case .name: return "Sort by Name"
        case .date: return "Sort by Date"
        case .size: return "Sort by Size"
        case .bundleID: return "Sort by Bundle ID"
        }
    }
}

// MARK: - ThemeManager

final class ThemeManager: ObservableObject {

    static let shared = ThemeManager()

    // ── Preset / colours ───────────────────────────────────────────────────
    @Published var preset: ThemePreset    = .bronzeVault { didSet { save() } }
    @Published var customAccentHex: String = "#B87333"   { didSet { save() } }

    // ── Card style ─────────────────────────────────────────────────────────
    @Published var cardStyle: ThemeCardStyle = .outlined  { didSet { save() } }

    // ── Background photo ───────────────────────────────────────────────────
    @Published var hasPhoto: Bool          = false        { didSet { save() } }
    @Published var photo: UIImage?         = nil
    @Published var photoBlur: Double       = 14           { didSet { save() } }
    @Published var photoDim: Double        = 0.50         { didSet { save() } }
    @Published var photoOpacity: Double    = 0.85         { didSet { save() } }

    // ── App Icon Style (Feather feature) ────────────────────────────────────
    @Published var appIconStyle: AppIconStyle = .system { didSet { save() } }

    // ── Signing Behavior (ZSign feature) ───────────────────────────────────
    @Published var signingBehavior: SigningBehavior = .ask { didSet { save() } }
    @Published var certificateValidation: CertificateValidation = .strict { didSet { save() } }

    // ── Repository Behavior (Feather feature) ────────────────────────────────
    @Published var repositoryBehavior: RepositoryBehavior = .manualRefresh { didSet { save() } }
    @Published var appSorting: AppSorting = .name { didSet { save() } }
    @Published var showAppIcons: Bool = true { didSet { save() } }

    // MARK: - Derived colours

    /// Current accent colour — either preset or custom.
    var accentColor: Color {
        preset == .custom ? Color(hex: customAccentHex) : Color(hex: preset.accentHex)
    }

    /// Returns .clear when a background photo is active so the photo shows through.
    var backgroundColor: Color {
        hasPhoto ? .clear : Color(hex: preset.bgHex)
    }

    var surfaceColor: Color { Color(hex: preset.surfaceHex) }

    var surface2Color: Color {
        // Slightly more prominent than surface
        Color(hex: preset.surfaceHex).opacity(0.95)
    }

    // MARK: - Photo I/O

    private var photoFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Theme/background.jpg")
    }

    func setPhoto(_ image: UIImage) {
        photo    = image
        hasPhoto = true
        Task.detached { [weak self] in
            self?.savePhoto(image)
        }
    }

    func removePhoto() {
        photo    = nil
        hasPhoto = false
        try? FileManager.default.removeItem(at: photoFileURL)
        save()
    }

    private func savePhoto(_ image: UIImage) {
        let dir = photoFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let maxSide: CGFloat = 1080
        let scale = min(maxSide / image.size.width, maxSide / image.size.height, 1)
        let sz    = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: sz)
        let resized  = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: sz)) }
        try? resized.jpegData(compressionQuality: 0.82)?.write(to: photoFileURL, options: .atomic)
    }

    // MARK: - Persistence

    private let ud = UserDefaults.standard

    func save() {
        ud.set(preset.rawValue,       forKey: "t.preset")
        ud.set(customAccentHex,       forKey: "t.customAccent")
        ud.set(cardStyle.rawValue,    forKey: "t.cardStyle")
        ud.set(hasPhoto,              forKey: "t.hasPhoto")
        ud.set(photoBlur,             forKey: "t.blur")
        ud.set(photoDim,              forKey: "t.dim")
        ud.set(photoOpacity,          forKey: "t.opacity")
        
        // Feather/ZSign options
        ud.set(appIconStyle.rawValue, forKey: "t.appIconStyle")
        ud.set(signingBehavior.rawValue, forKey: "t.signingBehavior")
        ud.set(certificateValidation.rawValue, forKey: "t.certValidation")
        ud.set(repositoryBehavior.rawValue, forKey: "t.repoBehavior")
        ud.set(appSorting.rawValue, forKey: "t.appSorting")
        ud.set(showAppIcons, forKey: "t.showAppIcons")
    }

    private init() {
        if let raw = ud.string(forKey: "t.preset"),
           let p   = ThemePreset(rawValue: raw)       { preset           = p   }
        if let hex = ud.string(forKey: "t.customAccent") { customAccentHex = hex }
        if let raw = ud.string(forKey: "t.cardStyle"),
           let cs  = ThemeCardStyle(rawValue: raw)    { cardStyle        = cs  }
        hasPhoto    = ud.bool(forKey: "t.hasPhoto")
        if ud.object(forKey: "t.blur")    != nil { photoBlur    = ud.double(forKey: "t.blur")    }
        if ud.object(forKey: "t.dim")     != nil { photoDim     = ud.double(forKey: "t.dim")     }
        if ud.object(forKey: "t.opacity") != nil { photoOpacity = ud.double(forKey: "t.opacity") }
        
        // Feather/ZSign options
        if let raw = ud.string(forKey: "t.appIconStyle"),
           let ais = AppIconStyle(rawValue: raw) { appIconStyle = ais }
        if let raw = ud.string(forKey: "t.signingBehavior"),
           let sb = SigningBehavior(rawValue: raw) { signingBehavior = sb }
        if let raw = ud.string(forKey: "t.certValidation"),
           let cv = CertificateValidation(rawValue: raw) { certificateValidation = cv }
        if let raw = ud.string(forKey: "t.repoBehavior"),
           let rb = RepositoryBehavior(rawValue: raw) { repositoryBehavior = rb }
        if let raw = ud.string(forKey: "t.appSorting"),
           let sorting = AppSorting(rawValue: raw) { appSorting = sorting }
        showAppIcons = ud.bool(forKey: "t.showAppIcons")

        if hasPhoto,
           let data = try? Data(contentsOf: photoFileURL),
           let img  = UIImage(data: data) {
            photo = img
        }
    }

    // MARK: - Background View

    /// A view that displays the current theme background (color or photo)
    var backgroundView: some View {
        Group {
            if let photo = photo, hasPhoto {
                // Photo background with customization
                GeometryReader { geometry in
                    ZStack {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            .blur(radius: CGFloat(self.photoBlur))
                            .opacity(self.photoOpacity)
                            .overlay(
                                Color.black.opacity(self.photoDim)
                            )
                    }
                }
                .ignoresSafeArea()
            } else {
                // Color background
                backgroundColor
                    .ignoresSafeArea()
            }
        }
    }
    
    /// Applies the current theme settings to the app
    func applyTheme() {
        // Apply UIKit appearance settings
        TabBarAppearance.apply()
        NavBarAppearance.apply()
        
        // Register fonts
        FontRegistration.registerFonts()
    }
}

// MARK: - View Modifiers

extension View {
    /// Applies the current theme background to this view
    func themeBackground() -> some View {
        self.background(ThemeManager.shared.backgroundView)
    }
    
    /// Applies the current theme accent color
    var themeAccent: Color {
        ThemeManager.shared.accentColor
    }
    
    /// Applies the current theme surface color
    var themeSurface: Color {
        ThemeManager.shared.surfaceColor
    }
    
    /// Applies the current theme surface2 color
    var themeSurface2: Color {
        ThemeManager.shared.surface2Color
    }
}