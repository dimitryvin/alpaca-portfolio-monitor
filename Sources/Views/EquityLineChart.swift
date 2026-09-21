import Charts
import SwiftUI

/// Line + area chart of a value series, shared by the portfolio and stock
/// detail screens. Hovering scrubs the series, showing the value and time under
/// the pointer.
///
/// 1D keeps a real time axis pinned to the trading session; every other range
/// plots on a collapsed index axis so weekends/holidays don't stretch it.
/// Expects at least two points — callers show their own empty state otherwise.
struct EquityLineChart: View {
    let points: [PortfolioPoint]
    let range: ChartRange
    let tint: Color

    @State private var selection: ChartSelection?

    var body: some View {
        Group {
            if range == .day, let xRange = ChartDomain.x(for: points, range: .day) {
                dayChart(xRange: xRange)
            } else {
                indexChart(series: ChartSeries(points: points, range: range))
            }
        }
        // A selection indexes into the series it was made on.
        .onChange(of: range) { selection = nil }
        .onChange(of: points) { selection = nil }
    }

    /// Intraday chart on a real time axis, pinned to the trading session.
    private func dayChart(xRange: ClosedRange<Date>) -> some View {
        let (lowerBound, upperBound) = yDomain(for: points.map(\.equity))
        return Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("Time", point.date),
                    yStart: .value("Min", lowerBound),
                    yEnd: .value("Value", point.equity)
                )
                .foregroundStyle(areaGradient)
                .interpolationMethod(.monotone)

                LineMark(x: .value("Time", point.date), y: .value("Value", point.equity))
                    .foregroundStyle(tint)
                    .interpolationMethod(.monotone)
            }
            if let selection {
                ChartScrubMarks(
                    x: .value("Time", selection.date),
                    y: .value("Value", selection.value),
                    tint: tint
                )
            }
        }
        .chartYScale(domain: lowerBound...upperBound)
        .chartXScale(domain: xRange)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4))
        }
        .chartScrubbing(selection: selection, label: readoutLabel) { fraction in
            selection = fraction.flatMap { ChartScrub.selection(atFraction: $0, in: points, domain: xRange) }
        }
    }

    /// Multi-day chart on a collapsed index axis so non-trading gaps disappear.
    private func indexChart(series: ChartSeries) -> some View {
        let (lowerBound, upperBound) = yDomain(for: series.points.map(\.equity))
        return Chart {
            ForEach(series.points) { point in
                AreaMark(
                    x: .value("t", point.index),
                    yStart: .value("Min", lowerBound),
                    yEnd: .value("Value", point.equity)
                )
                .foregroundStyle(areaGradient)
                .interpolationMethod(.monotone)

                LineMark(x: .value("t", point.index), y: .value("Value", point.equity))
                    .foregroundStyle(tint)
                    .interpolationMethod(.monotone)
            }
            if let selection {
                ChartScrubMarks(
                    x: .value("t", selection.index),
                    y: .value("Value", selection.value),
                    tint: tint
                )
            }
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
        .chartScrubbing(selection: selection, label: readoutLabel) { fraction in
            selection = fraction.flatMap { ChartScrub.selection(atFraction: $0, in: series) }
        }
    }

    /// "$12,345.67 · 10:45 AM" for the hovered point.
    private var readoutLabel: String? {
        selection.map {
            "\(CurrencyFormatter.full.string(from: $0.value)) · \(ChartScrub.timeLabel(for: $0.date, range: range))"
        }
    }

    private var areaGradient: LinearGradient {
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
