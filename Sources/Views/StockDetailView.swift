import SwiftUI

/// Detail screen for a single holding, pushed inside the popover's navigation
/// stack: current price, a range-switchable price chart (with a loading state),
/// position figures, and company reference details.
struct StockDetailView: View {
    @Environment(PortfolioStore.self) private var store

    let position: Position
    let onBack: () -> Void

    @State private var bars: [StockBar] = []
    @State private var asset: Asset?
    @State private var selectedRange: ChartRange = .day
    @State private var isChartLoading = false
    @State private var errorMessage: String?

    private var symbol: String { position.displaySymbol }
    private var points: [PortfolioPoint] { bars.points }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                backButton
                header
                rangePicker
                chart
                    // Room for the scrub readout band above the plot.
                    .frame(height: 140 + ChartScrubMetrics.readoutHeight)
                    .overlay {
                        if isChartLoading {
                            ProgressView()
                                .controlSize(.small)
                                .padding(8)
                                .background(.regularMaterial, in: .rect(cornerRadius: 8))
                        }
                    }
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Divider()
                positionSection
                if let asset {
                    Divider()
                    companySection(asset)
                }
            }
            .padding(14)
        }
        .frame(height: 480)
        .task { await loadAsset() }
        .task(id: selectedRange) { await loadBars() }
    }

    /// Explicit back control: the detail is swapped in place inside the popover
    /// (no NavigationStack), so it owns its own back affordance.
    private var backButton: some View {
        Button {
            onBack()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                Text("Portfolio")
            }
            .font(.callout)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(asset?.name ?? symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(CurrencyFormatter.full.string(from: position.currentPrice))
                .font(.system(.title2, design: .rounded).weight(.semibold))
            HStack(spacing: 4) {
                Text(PercentFormatter.signed(position.changeTodayPct))
                Text("today")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .foregroundStyle(changeColor(position.changeTodayPct))
        }
    }

    private var rangePicker: some View {
        Picker("Range", selection: $selectedRange) {
            ForEach(ChartRange.allCases) { range in
                Text(range.label).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    @ViewBuilder
    private var chart: some View {
        if points.count >= 2 {
            EquityLineChart(points: points, range: selectedRange, tint: chartChange >= 0 ? .green : .red)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.08))
                .overlay(
                    Text(isChartLoading ? "Loading…" : "No price data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                )
        }
    }

    /// Signed change across the charted series, used to tint the line.
    private var chartChange: Double {
        guard let first = points.first?.equity, let last = points.last?.equity else { return 0 }
        return last - first
    }

    private var positionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Position")
                .font(.caption)
                .foregroundStyle(.secondary)
            LazyVGrid(
                columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                alignment: .leading,
                spacing: 10
            ) {
                stat("Market Value", CurrencyFormatter.full.string(from: position.marketValue))
                stat(position.isOption ? "Contracts" : "Shares",
                     position.qty.formatted(.number.precision(.fractionLength(0...4))))
                if let avg = position.avgEntryPrice {
                    stat("Avg Entry", CurrencyFormatter.full.string(from: avg))
                }
                if let cost = position.costBasis {
                    stat("Cost Basis", CurrencyFormatter.full.string(from: cost))
                }
                stat("Total P/L",
                     CurrencyFormatter.full.signedString(from: position.unrealizedPL),
                     color: changeColor(position.unrealizedPL),
                     detail: PercentFormatter.signed(position.unrealizedPLPct))
                stat("Today's P/L",
                     CurrencyFormatter.full.signedString(from: position.unrealizedIntradayPL),
                     color: changeColor(position.unrealizedIntradayPL),
                     detail: PercentFormatter.signed(position.unrealizedIntradayPLPct))
            }
        }
    }

    private func companySection(_ asset: Asset) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("About")
                .font(.caption)
                .foregroundStyle(.secondary)
            infoRow("Name", asset.name)
            if let exchange = asset.exchange { infoRow("Exchange", exchange) }
            if let assetClass = asset.assetClass {
                infoRow("Class", assetClass.replacingOccurrences(of: "_", with: " ").capitalized)
            }
            if let status = asset.status { infoRow("Status", status.capitalized) }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.caption)
    }

    private func stat(_ title: String, _ value: String, color: Color = .primary, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Text(value)
                    .font(.system(.callout, design: .rounded).weight(.medium))
                    .foregroundStyle(color)
                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(color)
                }
            }
        }
    }

    // MARK: - Loading

    private func loadAsset() async {
        guard let credentials = store.credentials else { return }
        asset = try? await AlpacaClient(credentials: credentials).fetchAsset(symbol: symbol)
    }

    private func loadBars() async {
        guard let credentials = store.credentials else { return }
        isChartLoading = true
        errorMessage = nil
        do {
            bars = try await AlpacaClient(credentials: credentials).fetchBars(symbol: symbol, range: selectedRange)
            isChartLoading = false
        } catch {
            if Task.isCancelled { return } // superseded by a newer range selection
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            isChartLoading = false
        }
    }

    // MARK: - Helpers

    private func changeColor(_ value: Double) -> Color {
        value > 0 ? .green : (value < 0 ? .red : .secondary)
    }
}
