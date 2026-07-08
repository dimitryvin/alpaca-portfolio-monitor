import ComposableArchitecture
import Foundation

/// The Trades tab: executed fills newest-first, with realized P/L on sells and a
/// total. Loads lazily on first appearance; re-fetches on pull-to-refresh.
@Reducer
struct TradesFeature {
    @ObservableState
    struct State: Equatable {
        let credentials: Credentials
        var trades: [Trade] = []
        var isLoading = false
        var loaded = false
        var errorMessage: String?

        init(credentials: Credentials) {
            self.credentials = credentials
        }

        /// Total realized P/L across all sells that had a known cost basis.
        var totalRealizedPL: Double {
            trades.compactMap(\.realizedPL).reduce(0, +)
        }
    }

    enum Action {
        case delegate(Delegate)
        case onAppear
        case refreshRequested
        case tradesResponse(Result<[Trade], any Error>)

        @CasePathable
        enum Delegate {
            case reauthRequired
        }
    }

    @Dependency(\.alpacaAPI) var alpacaAPI

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return state.loaded ? .none : .send(.refreshRequested)

            case .refreshRequested:
                state.isLoading = true
                state.errorMessage = nil
                let credentials = state.credentials
                return .run { send in
                    do {
                        let trades = try await alpacaAPI.trades(credentials)
                        await send(.tradesResponse(.success(trades)))
                    } catch {
                        await send(.tradesResponse(.failure(error)))
                    }
                }

            case let .tradesResponse(.success(trades)):
                state.isLoading = false
                state.loaded = true
                state.trades = trades
                return .none

            case let .tradesResponse(.failure(error)):
                state.isLoading = false
                if let alpacaError = error as? AlpacaError, alpacaError == .unauthorized {
                    return .send(.delegate(.reauthRequired))
                }
                state.errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
