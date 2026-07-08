import ComposableArchitecture
import Foundation

/// Controllable dependency for reading/writing the paired account's credentials
/// in the iOS Keychain.
@DependencyClient
struct CredentialsClient: Sendable {
    var load: @Sendable () -> Credentials?
    var save: @Sendable (_ credentials: Credentials) throws -> Void
    var clear: @Sendable () -> Void
}

extension CredentialsClient: DependencyKey {
    static let liveValue = CredentialsClient(
        load: { KeychainCredentialsStore.load() },
        save: { try KeychainCredentialsStore.save($0) },
        clear: { KeychainCredentialsStore.clear() }
    )

    static let testValue = CredentialsClient()
}

extension DependencyValues {
    var credentials: CredentialsClient {
        get { self[CredentialsClient.self] }
        set { self[CredentialsClient.self] = newValue }
    }
}
