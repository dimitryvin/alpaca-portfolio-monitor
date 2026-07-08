import Charts
import SwiftUI

/// The equity line chart with a soft gradient fill, tinted by the period's change.
struct EquityChartView: View {
    let points: [PortfolioPoint]
    let change: Double

    var body: some View {
        if points.count < 2 {
            RoundedRectangle(cornerRadius: 16)
                .fill(.quaternary.opacity(0.4))
                .overlay {
                    Text("No chart data")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
        } else {
            Chart(points) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Equity", point.equity)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value("Time", point.date),
                    y: .value("Equity", point.equity)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    .linearGradient(
                        colors: [tint.opacity(0.25), tint.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(preset: .aligned, values: .automatic(desiredCount: 4))
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let equity = value.as(Double.self) {
                            Text(CurrencyFormatter.compact.string(from: equity))
                        }
                    }
                }
            }
            .chartPlotStyle { plot in
                plot.clipped()
            }
        }
    }

    private var tint: Color { Color.forChange(change) }

    private var yDomain: ClosedRange<Double> {
        let equities = points.map(\.equity)
        let lo = equities.min() ?? 0
        let hi = equities.max() ?? 1
        guard hi > lo else { return (lo - 1) ... (hi + 1) }
        let pad = (hi - lo) * 0.08
        return (lo - pad) ... (hi + pad)
    }
}
