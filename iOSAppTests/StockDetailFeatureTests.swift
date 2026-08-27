import ComposableArchitecture
import Foundation
import Testing
@testable import AlpacaMonitorMobile

@MainActor
struct StockDetailFeatureTests {
    private func makeStore() -> TestStoreOf<StockDetailFeature> {
        TestStore(
            initialState: StockDetailFeature.State(
                position: Fixtures.positions[0], credentials: Fixtures.credentials
            )
        ) {
            StockDetailFeature()
        } withDependencies: {
            $0.alpacaAPI.asset = { _, _ in Fixtures.appleAsset }
            $0.alpacaAPI.bars = { _, _, _ in Fixtures.bars }
        }
    }

    @Test
    func onAppearLoadsAssetAndBars() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.onAppear) {
            $0.isChartLoading = true
        }
        // Order between the two merged effects isn't guaranteed; assert the asset
        // via its own receive and drain the bars response, then check final state.
        await store.receive(\.assetResponse.success) {
            $0.asset = Fixtures.appleAsset
        }
        await store.skipReceivedActions()
        #expect(store.state.bars == Fixtures.bars)
        #expect(store.state.isChartLoading == false)
    }

    @Test
    func changingRangeShowsLoadingThenLoadsBars() async {
        let store = makeStore()

        await store.send(.rangeChanged(.week)) {
            $0.selectedRange = .week
            $0.isChartLoading = true
        }
        await store.receive(\.barsResponse.success) {
            $0.isChartLoading = false
            $0.bars = Fixtures.bars
        }
    }

    @Test
    func barsFailureSurfacesError() async {
        let store = TestStore(
            initialState: StockDetailFeature.State(
                position: Fixtures.positions[0], credentials: Fixtures.credentials
            )
        ) {
            StockDetailFeature()
        } withDependencies: {
            $0.alpacaAPI.asset = { _, _ in Fixtures.appleAsset }
            $0.alpacaAPI.bars = { _, _, _ in throw AlpacaError.http(500) }
        }

        await store.send(.rangeChanged(.week)) {
            $0.selectedRange = .week
            $0.isChartLoading = true
        }
        await store.receive(\.barsResponse.failure) {
            $0.isChartLoading = false
            $0.errorMessage = AlpacaError.http(500).errorDescription
        }
    }
}
