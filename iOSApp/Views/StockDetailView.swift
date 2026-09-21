import ComposableArchitecture
import SwiftUI

/// Detail screen for a single holding: current price, a range-switchable price
/// chart, position figures, and company reference details.
struct StockDetailView: View {
    @Bindable var store: StoreOf<StockDetailFeature>

    /// The chart point being scrubbed. Transient view state: it lives only for
    /// the duration of a gesture, so it stays out of the feature's state.
    @State private var scrub: ChartSelection?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                rangePicker
                chart
                if let message = store.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                positionSection
                companySection
            }
            .padding()
        }
        .navigationTitle(store.symbol)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.send(.onAppear) }
    }

    private var header: some View {
        let figures = headerFigures
        return VStack(alignment: .leading, spacing: 4) {
            Text(store.displayName)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(CurrencyFormatter.full.string(from: figures.price))
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .contentTransition(.numericText())
            HStack(spacing: 6) {
                Image(systemName: figures.percent >= 0 ? "arrow.up.right" : "arrow.down.right")
                Text(figures.caption)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.forChange(figures.percent))
        }
    }

    /// The headline price and change: the scrubbed point while the chart is
    /// being scrubbed (measured from the start of the range), else the live quote.
    private var headerFigures: (price: Double, percent: Double, caption: String) {
        guard let scrub else {
            let percent = store.position.changeTodayPct
            return (store.position.currentPrice, percent, "\(PercentFormatter.signed(percent)) today")
        }
        let percent = scrub.change(from: store.points.first?.equity ?? scrub.value).percent
        return (scrub.value, percent, PercentFormatter.signed(percent))
    }

    private var rangePicker: some View {
        Picker("Range", selection: $store.selectedRange.sending(\.rangeChanged)) {
            ForEach(ChartRange.allCases) { range in
                Text(range.label).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    private var chart: some View {
        EquityChartView(
            points: store.points,
            change: store.chartChange,
            range: store.selectedRange,
            selection: $scrub
        )
        // Room for the scrub readout band above the plot.
        .frame(height: 220 + ChartScrubMetrics.readoutHeight)
        .overlay {
            if store.isChartLoading {
                ProgressView()
                    .padding(10)
                    .background(.regularMaterial, in: .rect(cornerRadius: 10))
            }
        }
    }

    private var positionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Position")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                DetailTile(
                    label: "Market Value",
                    value: CurrencyFormatter.full.string(from: store.position.marketValue)
                )
                DetailTile(
                    label: store.position.isOption ? "Contracts" : "Shares",
                    value: store.position.qty.formatted(.number.precision(.fractionLength(0...4)))
                )
                if let avg = store.position.avgEntryPrice {
                    DetailTile(label: "Avg Entry", value: CurrencyFormatter.full.string(from: avg))
                }
                if let cost = store.position.costBasis {
                    DetailTile(label: "Cost Basis", value: CurrencyFormatter.full.string(from: cost))
                }
                DetailTile(
                    label: "Total P/L",
                    value: CurrencyFormatter.full.signedString(from: store.position.unrealizedPL),
                    detail: PercentFormatter.signed(store.position.unrealizedPLPct),
                    tint: Color.forChange(store.position.unrealizedPL)
                )
                DetailTile(
                    label: "Today's P/L",
                    value: CurrencyFormatter.full.signedString(from: store.position.unrealizedIntradayPL),
                    detail: PercentFormatter.signed(store.position.unrealizedIntradayPLPct),
                    tint: Color.forChange(store.position.unrealizedIntradayPL)
                )
            }
        }
    }

    @ViewBuilder
    private var companySection: some View {
        if let asset = store.asset {
            VStack(alignment: .leading, spacing: 10) {
                Text("About")
                    .font(.headline)
                InfoRow(label: "Name", value: asset.name)
                if let exchange = asset.exchange { InfoRow(label: "Exchange", value: exchange) }
                if let assetClass = asset.assetClass {
                    InfoRow(label: "Class", value: assetClass.replacingOccurrences(of: "_", with: " ").capitalized)
                }
                if let status = asset.status { InfoRow(label: "Status", value: status.capitalized) }
                if asset.fractionable == true { InfoRow(label: "Fractionable", value: "Yes") }
            }
        }
    }
}

private struct DetailTile: View {
    let label: String
    let value: String
    var detail: String?
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(tint)
            // Always reserve the detail line so every tile is the same height.
            Text(detail ?? " ")
                .font(.caption2)
                .foregroundStyle(tint)
                .opacity(detail == nil ? 0 : 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 14))
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

#Preview {
    NavigationStack {
        StockDetailView(
            store: Store(
                initialState: StockDetailFeature.State(
                    position: Position(
                        symbol: "AAPL", qtyRaw: "40", marketValueRaw: "9240.00",
                        currentPriceRaw: "231.00", unrealizedPLRaw: "612.40",
                        unrealizedPLPctRaw: "0.0709", changeTodayRaw: "0.0123",
                        avgEntryPriceRaw: "215.69", costBasisRaw: "8627.60",
                        assetClass: "us_equity", exchange: "NASDAQ"
                    ),
                    credentials: Credentials(keyID: "k", secret: "s")
                )
            ) {
                StockDetailFeature()
            } withDependencies: {
                $0.alpacaAPI = .preview
            }
        )
    }
}
