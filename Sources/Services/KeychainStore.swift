import Foundation
import Security

/// Alpaca API credentials (a key/secret pair).
struct Credentials: Equatable, Sendable {
    let keyID: String
    let secret: String

    var isValid: Bool { !keyID.isEmpty && !secret.isEmpty }
}

/// Stores Alpaca credentials in the macOS Keychain as a single generic-password
/// item. The key ID is stored as the account; the secret as the value.
///
/// Credentials are never written to logs or `UserDefaults`.
enum KeychainStore {
    private static let service = "com.alpacamonitor.AlpacaPortfolioMonitor"
    private static let account = "alpaca-credentials"

    /// Saves credentials, overwriting any existing item.
    static func save(_ credentials: Credentials) throws {
        guard credentials.isValid else { throw KeychainError.invalidInput }

        // Encode "keyID\nsecret" so both halves live in one item.
        let payload = "\(credentials.keyID)\n\(credentials.secret)"
        guard let data = payload.data(using: .utf8) else { throw KeychainError.invalidInput }

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
        guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
    }

    /// Loads credentials, or `nil` if none are stored.
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

    /// Removes stored credentials, if any.
    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: Error, Equatable {
    case invalidInput
    case unhandled(OSStatus)
}
