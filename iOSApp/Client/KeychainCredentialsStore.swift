import Foundation
import Security

/// Persists Alpaca credentials in the iOS Keychain as a single generic-password
/// item (key ID + secret encoded together). Mirrors the macOS `KeychainStore` but
/// uses the iOS app's own service identifier.
///
/// Credentials are never written to logs or `UserDefaults`.
enum KeychainCredentialsStore {
    private static let service = "com.alpacamonitor.mobile"
    private static let account = "alpaca-credentials"

    static func save(_ credentials: Credentials) throws {
        guard credentials.isValid else { throw KeychainCredentialsError.invalidInput }

        let payload = "\(credentials.keyID)\n\(credentials.secret)"
        guard let data = payload.data(using: .utf8) else { throw KeychainCredentialsError.invalidInput }

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        SecItemDelete(baseQuery as CFDictionary)

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainCredentialsError.unhandled(status) }
    }

    static func load() -> Credentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let payload = String(data: data, encoding: .utf8) else { return nil }

        let parts = payload.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let credentials = Credentials(keyID: String(parts[0]), secret: String(parts[1]))
        return credentials.isValid ? credentials : nil
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainCredentialsError: Error, Equatable {
    case invalidInput
    case unhandled(OSStatus)
}
