import SwiftUI

/// Equity line chart with a range picker. Re-fetches via the store when the
/// selected range changes.
struct PortfolioChartView: View {
    @Environment(PortfolioStore.self) private var store

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 8) {
            Picker("Range", selection: $store.selectedRange) {
                ForEach(ChartRange.allCases) { range in
                    Text(range.label).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            chart
                // The scrub readout takes a band above the plot; grow the frame
                // by the same amount so the plot itself keeps its size.
                .frame(height: 140 + ChartScrubMetrics.readoutHeight)
                .overlay {
                    if store.isChartLoading {
                        ProgressView()
                            .controlSize(.small)
                            .padding(8)
                            .background(.regularMaterial, in: .rect(cornerRadius: 8))
                    }
                }
        }
    }

    @ViewBuilder
    private var chart: some View {
        let points = store.history?.points ?? []
        if points.count >= 2 {
            let tint = (store.history?.overallChange ?? 0) >= 0 ? Color.green : Color.red
            EquityLineChart(points: points, range: store.selectedRange, tint: tint)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.08))
                .overlay(
                    Text(store.isLoading ? "Loading…" : "No data for this range")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                )
        }
    }
}
