import Foundation
import SwiftUI

// MARK: - App Settings Model

/// Global application settings that persist across app launches
final class Settings: ObservableObject, Codable {
    
    static let shared = Settings()
    
    // MARK: - UI Settings
    
    @Published var defaultTab: AppTab = .library
    @Published var cardStyle: ThemeCardStyle = .outlined
    @Published var showAnimations: Bool = true
    
    // MARK: - Behavior Settings
    
    @Published var autoImportFromRepos: Bool = false
    @Published var confirmDeletions: Bool = true
    @Published var showTips: Bool = true
    
    // MARK: - Developer Settings
    
    @Published var developerMode: Bool = false
    @Published var showDebugInfo: Bool = false
    @Published var logLevel: LogLevel = .info
    
    // MARK: - AI Settings
    
    @Published var aiApiKey: String = ""
    
    // MARK: - Advanced Settings
    
    @Published var maxConcurrentImports: Int = 3
    @Published var timeout: TimeInterval = 30
    @Published var cacheSize: Int = 500 // MB
    
    private let userDefaults = UserDefaults.standard
    private let key = "appSettings"
    
    init() {
        load()
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            userDefaults.set(encoded, forKey: key)
        }
    }
    
    private func load() {
        if let data = userDefaults.data(forKey: key) {
            do {
                let decoded = try JSONDecoder().decode(Settings.self, from: data)
                self.defaultTab = decoded.defaultTab
                self.cardStyle = decoded.cardStyle
                self.showAnimations = decoded.showAnimations
                self.autoImportFromRepos = decoded.autoImportFromRepos
                self.confirmDeletions = decoded.confirmDeletions
                self.showTips = decoded.showTips
        self.developerMode = decoded.developerMode
        self.showDebugInfo = decoded.showDebugInfo
        self.logLevel = decoded.logLevel
        self.aiApiKey = decoded.aiApiKey
        self.maxConcurrentImports = decoded.maxConcurrentImports
        self.timeout = decoded.timeout
        self.cacheSize = decoded.cacheSize
            } catch {
                print("Failed to decode settings: \(error)")
                // Reset to defaults if decoding fails
                resetToDefaults()
            }
        }
    }
    
    // MARK: - Codable Conformance
    
    private enum CodingKeys: String, CodingKey {
        case defaultTab, cardStyle, showAnimations, autoImportFromRepos, confirmDeletions
        case showTips, developerMode, showDebugInfo, logLevel, aiApiKey
        case maxConcurrentImports, timeout, cacheSize
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(defaultTab, forKey: .defaultTab)
        try container.encode(cardStyle, forKey: .cardStyle)
        try container.encode(showAnimations, forKey: .showAnimations)
        try container.encode(autoImportFromRepos, forKey: .autoImportFromRepos)
        try container.encode(confirmDeletions, forKey: .confirmDeletions)
        try container.encode(showTips, forKey: .showTips)
        try container.encode(developerMode, forKey: .developerMode)
        try container.encode(showDebugInfo, forKey: .showDebugInfo)
        try container.encode(logLevel, forKey: .logLevel)
        try container.encode(aiApiKey, forKey: .aiApiKey)
        try container.encode(maxConcurrentImports, forKey: .maxConcurrentImports)
        try container.encode(timeout, forKey: .timeout)
        try container.encode(cacheSize, forKey: .cacheSize)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultTab = try container.decode(AppTab.self, forKey: .defaultTab)
        cardStyle = try container.decode(ThemeCardStyle.self, forKey: .cardStyle)
        showAnimations = try container.decode(Bool.self, forKey: .showAnimations)
        autoImportFromRepos = try container.decode(Bool.self, forKey: .autoImportFromRepos)
        confirmDeletions = try container.decode(Bool.self, forKey: .confirmDeletions)
        showTips = try container.decode(Bool.self, forKey: .showTips)
        developerMode = try container.decode(Bool.self, forKey: .developerMode)
        showDebugInfo = try container.decode(Bool.self, forKey: .showDebugInfo)
        logLevel = try container.decode(LogLevel.self, forKey: .logLevel)
        aiApiKey = try container.decodeIfPresent(String.self, forKey: .aiApiKey) ?? ""
        maxConcurrentImports = try container.decode(Int.self, forKey: .maxConcurrentImports)
        timeout = try container.decode(TimeInterval.self, forKey: .timeout)
        cacheSize = try container.decode(Int.self, forKey: .cacheSize)
    }
    
    // MARK: - Reset
    
    func resetToDefaults() {
        defaultTab = .library
        cardStyle = .outlined
        showAnimations = true
        autoImportFromRepos = false
        confirmDeletions = true
        showTips = true
        developerMode = false
        showDebugInfo = false
        logLevel = .info
        aiApiKey = ""
        maxConcurrentImports = 3
        timeout = 30
        cacheSize = 500
        
        save()
    }
}

// MARK: - Log Level

enum LogLevel: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    
    case verbose
    case debug
    case info
    case warning
    case error
    case none
    
    var displayName: String {
        switch self {
        case .verbose: return "Verbose"
        case .debug: return "Debug"
        case .info: return "Info"
        case .warning: return "Warning"
        case .error: return "Error"
        case .none: return "None"
        }
    }
    
    var color: Color {
        switch self {
        case .verbose: return .purple
        case .debug: return .blue
        case .info: return .green
        case .warning: return .orange
        case .error: return .red
        case .none: return .gray
        }
    }
}

// MARK: - Settings Extension for Convenience

extension Settings {
    var isDeveloperMode: Bool {
        developerMode
    }
    
    var shouldConfirmDeletions: Bool {
        confirmDeletions
    }
    
    var shouldAutoImport: Bool {
        autoImportFromRepos
    }
}

// MARK: - Preview Settings

#if DEBUG
struct Settings_Previews: PreviewProvider {
    static var previews: some View {
        Text("Settings Preview")
            .previewLayout(.sizeThatFits)
    }
}
#endif