import ComposableArchitecture
import Foundation

/// The Portfolio tab: equity chart, key stats, and open positions for the
/// selected range. Fetches account, history, and positions concurrently, refreshes
/// on a 60-second timer while visible, and asks the parent to re-pair on 401/403.
@Reducer
struct PortfolioFeature {
    @ObservableState
    struct State: Equatable {
        let credentials: Credentials
        var account: Account?
        var history: PortfolioHistory?
        var positions: [Position] = []
        var selectedRange: ChartRange = .day
        var isLoading = false
        var errorMessage: String?
        var lastUpdated: Date?

        init(credentials: Credentials) {
            self.credentials = credentials
        }
    }

    enum Action {
        case dataResponse(Result<PortfolioData, any Error>)
        case delegate(Delegate)
        case onAppear
        case rangeChanged(ChartRange)
        case refreshRequested
        case timerTicked

        @CasePathable
        enum Delegate {
            case reauthRequired
        }
    }

    /// The three snapshots fetched together for one refresh.
    struct PortfolioData: Equatable, Sendable {
        let account: Account
        let history: PortfolioHistory
        let positions: [Position]
    }

    @Dependency(\.alpacaAPI) var alpacaAPI
    @Dependency(\.continuousClock) var clock
    @Dependency(\.date.now) var now

    enum CancelID { case refresh, timer }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .merge(
                    .send(.refreshRequested),
                    .run { send in
                        for await _ in clock.timer(interval: .seconds(60)) {
                            await send(.timerTicked)
                        }
                    }
                    .cancellable(id: CancelID.timer, cancelInFlight: true)
                )

            case .timerTicked:
                return .send(.refreshRequested)

            case .refreshRequested:
                state.isLoading = true
                state.errorMessage = nil
                let credentials = state.credentials
                let range = state.selectedRange
                return .run { send in
                    do {
                        async let account = alpacaAPI.account(credentials)
                        async let history = alpacaAPI.history(credentials, range)
                        async let positions = alpacaAPI.positions(credentials)
                        let data = try await PortfolioData(
                            account: account, history: history, positions: positions
                        )
                        await send(.dataResponse(.success(data)))
                    } catch {
                        await send(.dataResponse(.failure(error)))
                    }
                }
                .cancellable(id: CancelID.refresh, cancelInFlight: true)

            case let .rangeChanged(range):
                guard range != state.selectedRange else { return .none }
                state.selectedRange = range
                return .send(.refreshRequested)

            case let .dataResponse(.success(data)):
                state.isLoading = false
                state.account = data.account
                state.history = data.history
                state.positions = data.positions
                state.lastUpdated = now
                return .none

            case let .dataResponse(.failure(error)):
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
