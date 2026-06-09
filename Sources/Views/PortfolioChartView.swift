import SwiftUI
import Charts

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
                .frame(height: 140)
        }
    }

    @ViewBuilder
    private var chart: some View {
        let points = store.history?.points ?? []
        if points.count >= 2,
           let xRange = ChartDomain.x(for: points, range: store.selectedRange) {
            let tint = (store.history?.overallChange ?? 0) >= 0 ? Color.green : Color.red
            let (lowerBound, upperBound) = yDomain(for: points)
            Chart(points) { point in
                AreaMark(
                    x: .value("Time", point.date),
                    yStart: .value("Min", lowerBound),
                    yEnd: .value("Equity", point.equity)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [tint.opacity(0.25), tint.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Equity", point.equity)
                )
                .foregroundStyle(tint)
                .interpolationMethod(.monotone)
            }
            .chartYScale(domain: lowerBound...upperBound)
            .chartXScale(domain: xRange)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4))
            }
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

    /// A tight y-axis range that frames the data with ~12% padding, so intraday
    /// movement is visible instead of being flattened against a zero baseline.
    private func yDomain(for points: [PortfolioPoint]) -> (Double, Double) {
        let values = points.map(\.equity)
        let lo = values.min() ?? 0
        let hi = values.max() ?? 0
        let span = hi - lo
        let pad = span > 0 ? span * 0.12 : max(hi * 0.01, 1)
        return (lo - pad, hi + pad)
    }
}
