import Charts
import SwiftUI

/// The equity line chart with a soft gradient fill, tinted by the period's change.
///
/// Non-trading gaps (weekends, holidays) are collapsed for multi-day ranges by
/// plotting trading points on a sequential index axis; 1D keeps a real time axis.
struct EquityChartView: View {
    let points: [PortfolioPoint]
    let change: Double
    var range: ChartRange = .day

    var body: some View {
        if points.count < 2 {
            RoundedRectangle(cornerRadius: 16)
                .fill(.quaternary.opacity(0.4))
                .overlay {
                    Text("No chart data")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
        } else if range == .day {
            dateChart
        } else {
            indexChart(series: ChartSeries(points: points, range: range))
        }
    }

    /// Intraday chart on a real time axis.
    private var dateChart: some View {
        Chart(points) { point in
            LineMark(x: .value("Time", point.date), y: .value("Equity", point.equity))
                .interpolationMethod(.monotone)
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 2))

            AreaMark(x: .value("Time", point.date), y: .value("Equity", point.equity))
                .interpolationMethod(.monotone)
                .foregroundStyle(areaGradient)
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(preset: .aligned, values: .automatic(desiredCount: 4))
        }
        .chartYAxis { equityYAxis }
        .chartPlotStyle { $0.clipped() }
    }

    /// Multi-day chart on a collapsed index axis so non-trading gaps disappear.
    private func indexChart(series: ChartSeries) -> some View {
        Chart(series.points) { point in
            LineMark(x: .value("t", point.index), y: .value("Equity", point.equity))
                .interpolationMethod(.monotone)
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 2))

            AreaMark(x: .value("t", point.index), y: .value("Equity", point.equity))
                .interpolationMethod(.monotone)
                .foregroundStyle(areaGradient)
        }
        .chartYScale(domain: yDomain)
        .chartXScale(domain: series.xDomain)
        .chartXAxis {
            AxisMarks(values: series.tickIndices) { value in
                if let index = value.as(Int.self) {
                    AxisValueLabel { Text(series.label(for: index)) }
                }
            }
        }
        .chartYAxis { equityYAxis }
        .chartPlotStyle { $0.clipped() }
    }

    @AxisContentBuilder
    private var equityYAxis: some AxisContent {
        AxisMarks(position: .trailing) { value in
            AxisGridLine()
            AxisValueLabel {
                if let equity = value.as(Double.self) {
                    Text(CurrencyFormatter.compact.string(from: equity))
                }
            }
        }
    }

    private var tint: Color { Color.forChange(change) }

    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [tint.opacity(0.25), tint.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var yDomain: ClosedRange<Double> {
        let equities = points.map(\.equity)
        let lo = equities.min() ?? 0
        let hi = equities.max() ?? 1
        guard hi > lo else { return (lo - 1) ... (hi + 1) }
        let pad = (hi - lo) * 0.08
        return (lo - pad) ... (hi + pad)
    }
}
