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
            // 1D keeps a real time axis pinned to the session; every other range
            // plots on a collapsed index axis so weekends/holidays don't stretch it.
            if store.selectedRange == .day,
               let xRange = ChartDomain.x(for: points, range: .day) {
                dayChart(points: points, tint: tint, xRange: xRange)
            } else {
                indexChart(series: ChartSeries(points: points, range: store.selectedRange), tint: tint)
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

    /// Intraday chart on a real time axis, pinned to the trading session.
    private func dayChart(points: [PortfolioPoint], tint: Color, xRange: ClosedRange<Date>) -> some View {
        let (lowerBound, upperBound) = yDomain(for: points.map(\.equity))
        return Chart(points) { point in
            AreaMark(
                x: .value("Time", point.date),
                yStart: .value("Min", lowerBound),
                yEnd: .value("Equity", point.equity)
            )
            .foregroundStyle(areaGradient(tint))
            .interpolationMethod(.monotone)

            LineMark(x: .value("Time", point.date), y: .value("Equity", point.equity))
                .foregroundStyle(tint)
                .interpolationMethod(.monotone)
        }
        .chartYScale(domain: lowerBound...upperBound)
        .chartXScale(domain: xRange)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4))
        }
    }

    /// Multi-day chart on a collapsed index axis so non-trading gaps disappear.
    private func indexChart(series: ChartSeries, tint: Color) -> some View {
        let (lowerBound, upperBound) = yDomain(for: series.points.map(\.equity))
        return Chart(series.points) { point in
            AreaMark(
                x: .value("t", point.index),
                yStart: .value("Min", lowerBound),
                yEnd: .value("Equity", point.equity)
            )
            .foregroundStyle(areaGradient(tint))
            .interpolationMethod(.monotone)

            LineMark(x: .value("t", point.index), y: .value("Equity", point.equity))
                .foregroundStyle(tint)
                .interpolationMethod(.monotone)
        }
        .chartYScale(domain: lowerBound...upperBound)
        .chartXScale(domain: series.xDomain)
        .chartXAxis {
            AxisMarks(values: series.tickIndices) { value in
                if let index = value.as(Int.self) {
                    AxisValueLabel { Text(series.label(for: index)) }
                }
            }
        }
    }

    private func areaGradient(_ tint: Color) -> LinearGradient {
        LinearGradient(
            colors: [tint.opacity(0.25), tint.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// A tight y-axis range that frames the data with ~12% padding, so intraday
    /// movement is visible instead of being flattened against a zero baseline.
    private func yDomain(for values: [Double]) -> (Double, Double) {
        let lo = values.min() ?? 0
        let hi = values.max() ?? 0
        let span = hi - lo
        let pad = span > 0 ? span * 0.12 : max(hi * 0.01, 1)
        return (lo - pad, hi + pad)
    }
}
