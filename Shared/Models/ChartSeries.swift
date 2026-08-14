import Foundation

/// An equity series laid out for plotting so that non-trading gaps (nights,
/// weekends, holidays) don't stretch the line. Trading points are placed at
/// sequential integer indices, so consecutive sessions sit side by side and the
/// weekend never renders as a long flat segment.
///
/// Used for every range except `.day`, which keeps a real time axis so the
/// intraday line ends at the current moment within its pinned session.
struct ChartSeries: Equatable {
    /// A single plotted point at a collapsed index position.
    struct Point: Identifiable, Equatable {
        let index: Int
        let date: Date
        let equity: Double
        var id: Int { index }
    }

    let points: [Point]
    let range: ChartRange

    init(points rawPoints: [PortfolioPoint], range: ChartRange) {
        self.range = range
        self.points = rawPoints.enumerated().map { offset, point in
            Point(index: offset, date: point.date, equity: point.equity)
        }
    }

    /// Inclusive index domain for the x-axis (at least `0...1` so a scale exists).
    var xDomain: ClosedRange<Int> {
        0...max(points.count - 1, 1)
    }

    /// Up to four evenly spaced indices to mark on the x-axis.
    var tickIndices: [Int] {
        let count = points.count
        guard count > 1 else { return count == 1 ? [0] : [] }
        let desired = min(4, count)
        let indices = (0..<desired).map { step in
            Int((Double(step) * Double(count - 1) / Double(desired - 1)).rounded())
        }
        // Round-to-nearest can collide on small series; keep them distinct.
        return Array(Set(indices)).sorted()
    }

    /// The date label for a plotted index, formatted for the current range.
    func label(for index: Int) -> String {
        guard index >= 0, index < points.count else { return "" }
        return Self.formatter(for: range).string(from: points[index].date)
    }

    private static func formatter(for range: ChartRange) -> DateFormatter {
        let formatter = DateFormatter()
        switch range {
        case .day:
            formatter.dateFormat = "h:mm a"
        case .week, .month, .threeMonths:
            formatter.dateFormat = "MMM d"
        case .year, .all:
            formatter.dateFormat = "MMM ''yy"
        }
        return formatter
    }
}
