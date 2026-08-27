import ComposableArchitecture
import Foundation

/// The stock detail screen: a range-switchable price chart plus company and
/// position details for one holding. Loads the asset's reference data once and
/// re-fetches price bars whenever the range changes, showing a loading state
/// while the new range is in flight.
@Reducer
struct StockDetailFeature {
    @ObservableState
    struct State: Equatable, Identifiable {
        let credentials: Credentials
        /// The tapped position (drives the position-details section and header P/L).
        let position: Position
        /// The symbol charted: the underlying ticker for options, else the raw symbol.
        let symbol: String
        var asset: Asset?
        var bars: [StockBar] = []
        var selectedRange: ChartRange = .day
        var isChartLoading = false
        var errorMessage: String?

        var id: String { position.id }

        init(position: Position, credentials: Credentials) {
            self.credentials = credentials
            self.position = position
            self.symbol = position.displaySymbol
        }

        /// Chart points (close over time) for the loaded bars.
        var points: [PortfolioPoint] { bars.points }

        /// Signed change across the charted series, used to tint the chart.
        var chartChange: Double {
            guard let first = points.first?.equity, let last = points.last?.equity else { return 0 }
            return last - first
        }

        /// The company name to show, falling back to the ticker until it loads.
        var displayName: String { asset?.name ?? symbol }
    }

    enum Action {
        case onAppear
        case rangeChanged(ChartRange)
        case assetResponse(Result<Asset, any Error>)
        case barsResponse(Result<[StockBar], any Error>)
    }

    @Dependency(\.alpacaAPI) var alpacaAPI

    enum CancelID { case bars }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // Only load once; re-appearing (e.g. after backgrounding) keeps data.
                guard state.bars.isEmpty, state.asset == nil else { return .none }
                state.isChartLoading = true
                state.errorMessage = nil
                let credentials = state.credentials
                let symbol = state.symbol
                let range = state.selectedRange
                return .merge(
                    .run { send in
                        await send(.assetResponse(Result { try await alpacaAPI.asset(credentials, symbol) }))
                    },
                    .run { send in
                        await send(.barsResponse(Result { try await alpacaAPI.bars(credentials, symbol, range) }))
                    }
                    .cancellable(id: CancelID.bars, cancelInFlight: true)
                )

            case let .rangeChanged(range):
                guard range != state.selectedRange else { return .none }
                state.selectedRange = range
                state.isChartLoading = true
                state.errorMessage = nil
                let credentials = state.credentials
                let symbol = state.symbol
                return .run { send in
                    await send(.barsResponse(Result { try await alpacaAPI.bars(credentials, symbol, range) }))
                }
                .cancellable(id: CancelID.bars, cancelInFlight: true)

            case let .assetResponse(.success(asset)):
                state.asset = asset
                return .none

            case .assetResponse(.failure):
                // Non-fatal: the ticker stands in for the missing company name.
                return .none

            case let .barsResponse(.success(bars)):
                state.isChartLoading = false
                state.bars = bars
                state.errorMessage = nil
                return .none

            case let .barsResponse(.failure(error)):
                state.isChartLoading = false
                state.errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
                return .none
            }
        }
    }
}
