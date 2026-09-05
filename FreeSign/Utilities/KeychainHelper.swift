import Foundation
import Security

enum KeychainHelper {
    private enum Keys {
        static let aiService = "com.freesign.ai"
        static let certificateService = "com.freesign.certificates"
    }

    // MARK: - AI provider API keys

    static func save(providerID: UUID, apiKey: String) async -> Bool {
        save(value: apiKey, service: Keys.aiService, account: providerID.uuidString)
    }

    static func load(providerID: UUID) async -> String? {
        load(service: Keys.aiService, account: providerID.uuidString)
    }

    static func delete(providerID: UUID) async -> Bool {
        delete(service: Keys.aiService, account: providerID.uuidString)
    }

    /// Deletes every provider key belonging to FreeSign. This is used only by
    /// the explicit AI-data erasure flow, not by ordinary provider edits.
    static func deleteAllAIProviderKeys() async -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Keys.aiService
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    static func hasKey(providerID: UUID) async -> Bool {
        hasValue(service: Keys.aiService, account: providerID.uuidString)
    }

    /// Synchronous lookup used while building an outbound request. The actual
    /// Security framework call is synchronous; the async variants above simply
    /// match the SwiftUI callers that persist a new value in a Task.
    static func loadSync(providerID: UUID) -> String? {
        load(service: Keys.aiService, account: providerID.uuidString)
    }

    // MARK: - Certificate passwords

    /// New certificate imports leave `Certificate.password` empty in metadata
    /// and store a non-empty password in the protected iOS Keychain instead.
    static func saveCertificatePassword(certificateID: UUID, password: String) async -> Bool {
        guard !password.isEmpty else {
            return delete(service: Keys.certificateService, account: certificateID.uuidString)
        }
        return save(value: password, service: Keys.certificateService, account: certificateID.uuidString)
    }

    static func loadCertificatePasswordSync(certificateID: UUID) -> String? {
        load(service: Keys.certificateService, account: certificateID.uuidString)
    }

    static func deleteCertificatePassword(certificateID: UUID) async -> Bool {
        delete(service: Keys.certificateService, account: certificateID.uuidString)
    }

    // MARK: - Shared Security helpers

    private static func save(value: String, service: String, account: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let identityQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(identityQuery as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    private static func load(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
    }

    private static func delete(service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private static func hasValue(service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }
}
