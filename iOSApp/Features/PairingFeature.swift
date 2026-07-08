import ComposableArchitecture
import Foundation

/// Onboarding: pair the phone with an Alpaca account by scanning the QR code the
/// macOS app shows, or by entering the key/secret manually (e.g. in the Simulator,
/// which has no camera). Scanned/entered credentials are validated with a single
/// `GET /v2/account` call, saved to the Keychain, and handed to the parent.
@Reducer
struct PairingFeature {
    @ObservableState
    struct State: Equatable {
        var manualKeyID = ""
        var manualSecret = ""
        var showManualEntry = false
        var isValidating = false
        var errorMessage: String?
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case connectManuallyTapped
        case delegate(Delegate)
        case scanned(String)
        case validationResponse(Result<Credentials, any Error>)

        @CasePathable
        enum Delegate {
            case paired(Credentials)
        }
    }

    @Dependency(\.alpacaAPI) var alpacaAPI
    @Dependency(\.credentials) var credentialsStore

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding, .delegate:
                return .none

            case .connectManuallyTapped:
                let credentials = Credentials(
                    keyID: state.manualKeyID.trimmingCharacters(in: .whitespacesAndNewlines),
                    secret: state.manualSecret.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                guard credentials.isValid else {
                    state.errorMessage = "Enter both your API key ID and secret."
                    return .none
                }
                return validate(credentials, &state)

            case let .scanned(raw):
                guard !state.isValidating else { return .none }
                guard let payload = PairingPayload.decode(raw) else {
                    state.errorMessage = "That isn't a valid Alpaca Monitor pairing code."
                    return .none
                }
                return validate(payload.credentials, &state)

            case let .validationResponse(.success(credentials)):
                state.isValidating = false
                return .run { send in
                    try? credentialsStore.save(credentials)
                    await send(.delegate(.paired(credentials)))
                }

            case let .validationResponse(.failure(error)):
                state.isValidating = false
                if let alpacaError = error as? AlpacaError, alpacaError == .unauthorized {
                    state.errorMessage = "Those keys were rejected by Alpaca. Double-check them and try again."
                } else {
                    state.errorMessage = (error as? LocalizedError)?.errorDescription
                        ?? "Couldn't connect. Check your network and try again."
                }
                return .none
            }
        }
    }

    /// Marks validation in-flight and kicks off the `GET /v2/account` round-trip.
    private func validate(_ credentials: Credentials, _ state: inout State) -> Effect<Action> {
        state.isValidating = true
        state.errorMessage = nil
        return .run { send in
            do {
                _ = try await alpacaAPI.account(credentials)
                await send(.validationResponse(.success(credentials)))
            } catch {
                await send(.validationResponse(.failure(error)))
            }
        }
    }
}
