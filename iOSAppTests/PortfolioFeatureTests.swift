import ComposableArchitecture
import Foundation
import Testing
@testable import AlpacaMonitorMobile

@MainActor
struct PortfolioFeatureTests {
    private func makeStore() -> TestStoreOf<PortfolioFeature> {
        TestStore(initialState: PortfolioFeature.State(credentials: Fixtures.credentials)) {
            PortfolioFeature()
        } withDependencies: {
            $0.alpacaAPI.account = { _ in Fixtures.account }
            $0.alpacaAPI.history = { _, _ in Fixtures.history }
            $0.alpacaAPI.positions = { _ in Fixtures.positions }
            $0.alpacaAPI.asset = { _, _ in Fixtures.appleAsset }
            $0.date = .constant(Date(timeIntervalSince1970: 1_720_003_600))
        }
    }

    @Test
    func refreshPopulatesData() async {
        let store = makeStore()

        await store.send(.refreshRequested) {
            $0.isLoading = true
        }
        await store.receive(\.dataResponse.success) {
            $0.isLoading = false
            $0.account = Fixtures.account
            $0.history = Fixtures.history
            $0.positions = Fixtures.positions
            $0.lastUpdated = Date(timeIntervalSince1970: 1_720_003_600)
        }
        await store.receive(\.assetsResponse) {
            $0.assets = ["AAPL": Fixtures.appleAsset]
        }
    }

    @Test
    func changingRangeRefetches() async {
        let store = makeStore()

        await store.send(.rangeChanged(.week)) {
            $0.selectedRange = .week
            $0.isChartLoading = true
        }
        await store.receive(\.refreshRequested) {
            $0.isLoading = true
        }
        await store.receive(\.dataResponse.success) {
            $0.isLoading = false
            $0.isChartLoading = false
            $0.account = Fixtures.account
            $0.history = Fixtures.history
            $0.positions = Fixtures.positions
            $0.lastUpdated = Date(timeIntervalSince1970: 1_720_003_600)
        }
        await store.receive(\.assetsResponse) {
            $0.assets = ["AAPL": Fixtures.appleAsset]
        }
    }

    @Test
    func tappingPositionOpensDetail() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.positionTapped(Fixtures.positions[0])) {
            $0.stockDetail = StockDetailFeature.State(
                position: Fixtures.positions[0], credentials: Fixtures.credentials
            )
        }
    }

    @Test
    func unauthorizedAsksParentToReauth() async {
        let store = TestStore(initialState: PortfolioFeature.State(credentials: Fixtures.credentials)) {
            PortfolioFeature()
        } withDependencies: {
            $0.alpacaAPI.account = { _ in throw AlpacaError.unauthorized }
            $0.alpacaAPI.history = { _, _ in Fixtures.history }
            $0.alpacaAPI.positions = { _ in Fixtures.positions }
            $0.date = .constant(Date(timeIntervalSince1970: 0))
        }

        await store.send(.refreshRequested) {
            $0.isLoading = true
        }
        await store.receive(\.dataResponse.failure) {
            $0.isLoading = false
        }
        await store.receive(\.delegate.reauthRequired)
    }
}
