import Foundation
import SwiftUI

@Observable
final class AISettings: Codable {
    static let shared = AISettings()

    var activeProviderID: UUID?
    var providerConfigs: [AIProviderConfiguration] = []
    var defaultAction: AIAction = .explain
    /// Detailed app, source, and file metadata is never sent to a provider
    /// until the user explicitly enables contextual assistance.
    var sendContextByDefault: Bool = false
    var showAssistantInSettings: Bool = true

    var activeProvider: AIProviderConfiguration? {
        guard let id = activeProviderID,
              let config = providerConfigs.first(where: { $0.id == id })
        else { return nil }
        return config
    }

    var hasActiveProvider: Bool {
        activeProvider != nil
    }

    private let storageKey = "ai.settings"

    init() {
        load()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(AISettings.self, from: data)
        else { return }
        self.activeProviderID = decoded.activeProviderID
        self.providerConfigs = decoded.providerConfigs
        self.defaultAction = decoded.defaultAction
        self.sendContextByDefault = decoded.sendContextByDefault
        self.showAssistantInSettings = decoded.showAssistantInSettings
    }

    func resetToDefaults() {
        activeProviderID = nil
        providerConfigs = []
        defaultAction = .explain
        sendContextByDefault = false
        showAssistantInSettings = true
        save()
    }

    /// Erases all FreeSign AI configuration, provider API keys, and locally
    /// stored conversations. The caller must obtain user confirmation first.
    @discardableResult
    func eraseAllData() async -> Bool {
        let keysDeleted = await KeychainHelper.deleteAllAIProviderKeys()
        activeProviderID = nil
        providerConfigs = []
        defaultAction = .explain
        sendContextByDefault = false
        showAssistantInSettings = true
        UserDefaults.standard.removeObject(forKey: storageKey)
        AIService.shared.eraseLocalData()
        return keysDeleted
    }

    func addProvider(_ config: AIProviderConfiguration) {
        providerConfigs.append(config)
        save()
    }

    func updateProvider(_ config: AIProviderConfiguration) {
        guard let idx = providerConfigs.firstIndex(where: { $0.id == config.id }) else { return }
        providerConfigs[idx] = config
        save()
    }

    func deleteProvider(id: UUID) {
        providerConfigs.removeAll { $0.id == id }
        if activeProviderID == id {
            activeProviderID = nil
        }
        save()
    }

    func setActiveProvider(id: UUID) {
        activeProviderID = id
        for i in providerConfigs.indices {
            providerConfigs[i].isActive = providerConfigs[i].id == id
        }
        save()
    }

    func deactivateProvider() {
        activeProviderID = nil
        for i in providerConfigs.indices {
            providerConfigs[i].isActive = false
        }
        save()
    }

    enum CodingKeys: String, CodingKey {
        case activeProviderID, providerConfigs, defaultAction, sendContextByDefault, showAssistantInSettings
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(activeProviderID, forKey: .activeProviderID)
        try container.encode(providerConfigs, forKey: .providerConfigs)
        try container.encode(defaultAction, forKey: .defaultAction)
        try container.encode(sendContextByDefault, forKey: .sendContextByDefault)
        try container.encode(showAssistantInSettings, forKey: .showAssistantInSettings)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        activeProviderID = try container.decodeIfPresent(UUID.self, forKey: .activeProviderID)
        providerConfigs = try container.decodeIfPresent([AIProviderConfiguration].self, forKey: .providerConfigs) ?? []
        defaultAction = try container.decodeIfPresent(AIAction.self, forKey: .defaultAction) ?? .explain
        sendContextByDefault = try container.decodeIfPresent(Bool.self, forKey: .sendContextByDefault) ?? false
        showAssistantInSettings = try container.decodeIfPresent(Bool.self, forKey: .showAssistantInSettings) ?? true
    }
}
