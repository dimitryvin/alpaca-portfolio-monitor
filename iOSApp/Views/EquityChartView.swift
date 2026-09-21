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
    /// The point being scrubbed (long-press, then drag), or `nil`. Owned by the
    /// parent so its header can show the scrubbed value in place of the latest.
    @Binding var selection: ChartSelection?

    var body: some View {
        Group {
            if points.count < 2 {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.quaternary.opacity(0.4))
                    .overlay {
                        Text("No chart data")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
            } else if range == .day, let xRange = ChartDomain.x(for: points, range: .day) {
                dateChart(xRange: xRange)
            } else {
                indexChart(series: ChartSeries(points: points, range: range))
            }
        }
        .sensoryFeedback(.selection, trigger: selection?.index)
        // A selection indexes into the series it was made on.
        .onChange(of: range) { selection = nil }
        .onChange(of: points) { selection = nil }
    }

    /// Intraday chart on a real time axis, pinned to the trading session so the
    /// line ends at the current time of day instead of stretching full width.
    private func dateChart(xRange: ClosedRange<Date>) -> some View {
        Chart {
            ForEach(points) { point in
                LineMark(x: .value("Time", point.date), y: .value("Equity", point.equity))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(tint)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(x: .value("Time", point.date), y: .value("Equity", point.equity))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(areaGradient)
            }
            if let selection {
                ChartScrubMarks(
                    x: .value("Time", selection.date),
                    y: .value("Equity", selection.value),
                    tint: tint
                )
            }
        }
        .chartYScale(domain: yDomain)
        .chartXScale(domain: xRange)
        .chartXAxis {
            AxisMarks(preset: .aligned, values: .automatic(desiredCount: 4))
        }
        .chartYAxis { equityYAxis }
        .chartPlotStyle { $0.clipped() }
        .chartScrubbing(selection: selection, label: readoutLabel) { fraction in
            selection = fraction.flatMap { ChartScrub.selection(atFraction: $0, in: points, domain: xRange) }
        }
    }

    /// Multi-day chart on a collapsed index axis so non-trading gaps disappear.
    private func indexChart(series: ChartSeries) -> some View {
        Chart {
            ForEach(series.points) { point in
                LineMark(x: .value("t", point.index), y: .value("Equity", point.equity))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(tint)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(x: .value("t", point.index), y: .value("Equity", point.equity))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(areaGradient)
            }
            if let selection {
                ChartScrubMarks(
                    x: .value("t", selection.index),
                    y: .value("Equity", selection.value),
                    tint: tint
                )
            }
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
        .chartScrubbing(selection: selection, label: readoutLabel) { fraction in
            selection = fraction.flatMap { ChartScrub.selection(atFraction: $0, in: series) }
        }
    }

    /// When the scrubbed point was recorded; its value is shown in the parent's header.
    private var readoutLabel: String? {
        selection.map { ChartScrub.timeLabel(for: $0.date, range: range) }
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
