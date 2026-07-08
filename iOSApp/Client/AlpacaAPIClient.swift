import ComposableArchitecture
import Foundation

/// Controllable dependency wrapping the shared, read-only `AlpacaClient`.
///
/// Each endpoint takes the account's `Credentials` so a single client value can
/// serve any paired account. The live implementation builds an `AlpacaClient`
/// per call (it is a cheap value type); tests and previews override the closures.
@DependencyClient
struct AlpacaAPIClient: Sendable {
    var account: @Sendable (_ credentials: Credentials) async throws -> Account
    var history: @Sendable (_ credentials: Credentials, _ range: ChartRange) async throws -> PortfolioHistory
    var positions: @Sendable (_ credentials: Credentials) async throws -> [Position]
    var trades: @Sendable (_ credentials: Credentials) async throws -> [Trade]
}

extension AlpacaAPIClient: DependencyKey {
    static let liveValue = AlpacaAPIClient(
        account: { try await AlpacaClient(credentials: $0).fetchAccount() },
        history: { try await AlpacaClient(credentials: $0).fetchPortfolioHistory(range: $1) },
        positions: { try await AlpacaClient(credentials: $0).fetchPositions() },
        trades: {
            let activities = try await AlpacaClient(credentials: $0).fetchActivities()
            return TradeBuilder.build(from: activities)
        }
    )

    /// All endpoints unimplemented: tests must override the ones they exercise.
    static let testValue = AlpacaAPIClient()
}

extension DependencyValues {
    var alpacaAPI: AlpacaAPIClient {
        get { self[AlpacaAPIClient.self] }
        set { self[AlpacaAPIClient.self] = newValue }
    }
}
