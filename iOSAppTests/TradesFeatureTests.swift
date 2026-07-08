import ComposableArchitecture
import Testing
@testable import AlpacaMonitorMobile

@MainActor
struct TradesFeatureTests {
    @Test
    func onAppearLoadsTradesAndComputesTotal() async {
        let store = TestStore(initialState: TradesFeature.State(credentials: Fixtures.credentials)) {
            TradesFeature()
        } withDependencies: {
            $0.alpacaAPI.trades = { _ in Fixtures.trades }
        }

        await store.send(.onAppear)
        await store.receive(\.refreshRequested) {
            $0.isLoading = true
        }
        await store.receive(\.tradesResponse.success) {
            $0.isLoading = false
            $0.loaded = true
            $0.trades = Fixtures.trades
        }

        #expect(store.state.totalRealizedPL == 150)
    }

    @Test
    func onAppearIsNoOpWhenAlreadyLoaded() async {
        var initial = TradesFeature.State(credentials: Fixtures.credentials)
        initial.loaded = true
        let store = TestStore(initialState: initial) {
            TradesFeature()
        }

        await store.send(.onAppear)
    }

    @Test
    func unauthorizedAsksParentToReauth() async {
        let store = TestStore(initialState: TradesFeature.State(credentials: Fixtures.credentials)) {
            TradesFeature()
        } withDependencies: {
            $0.alpacaAPI.trades = { _ in throw AlpacaError.unauthorized }
        }

        await store.send(.refreshRequested) {
            $0.isLoading = true
        }
        await store.receive(\.tradesResponse.failure) {
            $0.isLoading = false
        }
        await store.receive(\.delegate.reauthRequired)
    }
}
