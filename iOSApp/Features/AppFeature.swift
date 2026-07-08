import ComposableArchitecture
import Foundation

/// Root feature. The app is always in exactly one of two modes — pairing (no
/// stored credentials) or the paired dashboard — modeled as two optional child
/// states with exactly one non-nil at a time. Owns the transitions between them:
/// pairing success, disconnect, and forced re-auth.
@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var pairing: PairingFeature.State?
        var dashboard: DashboardFeature.State?
    }

    enum Action {
        case dashboard(DashboardFeature.Action)
        case pairing(PairingFeature.Action)
    }

    @Dependency(\.credentials) var credentialsStore

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .pairing(.delegate(.paired(credentials))):
                state.pairing = nil
                state.dashboard = DashboardFeature.State(credentials: credentials)
                return .none

            case .dashboard(.delegate(.signOut)),
                 .dashboard(.delegate(.reauthRequired)):
                credentialsStore.clear()
                state.dashboard = nil
                state.pairing = PairingFeature.State()
                return .none

            case .dashboard, .pairing:
                return .none
            }
        }
        .ifLet(\.pairing, action: \.pairing) {
            PairingFeature()
        }
        .ifLet(\.dashboard, action: \.dashboard) {
            DashboardFeature()
        }
    }

    /// Picks the initial screen from stored credentials, avoiding a flash of the
    /// pairing UI when the phone is already paired.
    static func initialState() -> State {
        @Dependency(\.credentials) var credentialsStore
        if let credentials = credentialsStore.load() {
            return State(dashboard: DashboardFeature.State(credentials: credentials))
        }
        return State(pairing: PairingFeature.State())
    }
}
