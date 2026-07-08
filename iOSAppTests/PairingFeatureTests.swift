import ComposableArchitecture
import Testing
@testable import AlpacaMonitorMobile

@MainActor
struct PairingFeatureTests {
    @Test
    func manualConnectValidatesSavesAndPairs() async {
        let saved = LockIsolated<Credentials?>(nil)
        var initial = PairingFeature.State()
        initial.manualKeyID = Fixtures.credentials.keyID
        initial.manualSecret = Fixtures.credentials.secret

        let store = TestStore(initialState: initial) {
            PairingFeature()
        } withDependencies: {
            $0.alpacaAPI.account = { _ in Fixtures.account }
            $0.credentials.save = { saved.setValue($0) }
        }

        await store.send(.connectManuallyTapped) {
            $0.isValidating = true
        }
        await store.receive(\.validationResponse.success) {
            $0.isValidating = false
        }
        await store.receive(\.delegate.paired, Fixtures.credentials)

        #expect(saved.value == Fixtures.credentials)
    }

    @Test
    func manualConnectWithBlankFieldsShowsError() async {
        let store = TestStore(initialState: PairingFeature.State()) {
            PairingFeature()
        }

        await store.send(.connectManuallyTapped) {
            $0.errorMessage = "Enter both your API key ID and secret."
        }
    }

    @Test
    func rejectedKeysSurfaceErrorAndDoNotPair() async {
        var initial = PairingFeature.State()
        initial.manualKeyID = Fixtures.credentials.keyID
        initial.manualSecret = Fixtures.credentials.secret

        let store = TestStore(initialState: initial) {
            PairingFeature()
        } withDependencies: {
            $0.alpacaAPI.account = { _ in throw AlpacaError.unauthorized }
        }

        await store.send(.connectManuallyTapped) {
            $0.isValidating = true
        }
        await store.receive(\.validationResponse.failure) {
            $0.isValidating = false
            $0.errorMessage = "Those keys were rejected by Alpaca. Double-check them and try again."
        }
    }

    @Test
    func scanningValidCodePairs() async {
        let raw = PairingPayload.encode(Fixtures.credentials)
        let store = TestStore(initialState: PairingFeature.State()) {
            PairingFeature()
        } withDependencies: {
            $0.alpacaAPI.account = { _ in Fixtures.account }
            $0.credentials.save = { _ in }
        }

        await store.send(.scanned(raw)) {
            $0.isValidating = true
        }
        await store.receive(\.validationResponse.success) {
            $0.isValidating = false
        }
        await store.receive(\.delegate.paired, Fixtures.credentials)
    }

    @Test
    func scanningGarbageShowsError() async {
        let store = TestStore(initialState: PairingFeature.State()) {
            PairingFeature()
        }

        await store.send(.scanned("not a pairing code")) {
            $0.errorMessage = "That isn't a valid Alpaca Monitor pairing code."
        }
    }
}
