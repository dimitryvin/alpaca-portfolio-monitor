import ComposableArchitecture
import Foundation

/// The paired experience: a tab bar over the Portfolio and Trades features, plus a
/// disconnect control. Bubbles a re-auth request from either child up to the app.
@Reducer
struct DashboardFeature {
    @ObservableState
    struct State: Equatable {
        let credentials: Credentials
        var selectedTab: Tab = .portfolio
        var portfolio: PortfolioFeature.State
        var trades: TradesFeature.State

        init(credentials: Credentials) {
            self.credentials = credentials
            self.portfolio = PortfolioFeature.State(credentials: credentials)
            self.trades = TradesFeature.State(credentials: credentials)
        }

        enum Tab: String, CaseIterable, Identifiable, Sendable {
            case portfolio = "Portfolio"
            case trades = "Trades"
            var id: String { rawValue }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case disconnectTapped
        case portfolio(PortfolioFeature.Action)
        case trades(TradesFeature.Action)

        @CasePathable
        enum Delegate {
            case reauthRequired
            case signOut
        }
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Scope(state: \.portfolio, action: \.portfolio) { PortfolioFeature() }
        Scope(state: \.trades, action: \.trades) { TradesFeature() }
        Reduce { state, action in
            switch action {
            case .disconnectTapped:
                return .send(.delegate(.signOut))

            case .portfolio(.delegate(.reauthRequired)),
                 .trades(.delegate(.reauthRequired)):
                return .send(.delegate(.reauthRequired))

            case .binding, .delegate, .portfolio, .trades:
                return .none
            }
        }
    }
}
