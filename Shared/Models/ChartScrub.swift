import Foundation

/// The data point under the scrub cursor (mouse hover on macOS, long-press drag
/// on iOS).
struct ChartSelection: Equatable, Sendable {
    /// Position of the point within the plotted series.
    let index: Int
    let date: Date
    let value: Double
    /// Where the point sits across the plot's width (`0...1`), so a readout can
    /// be aligned with the marker rather than with the raw cursor position.
    let fraction: Double

    /// Signed change from `baseline` to this point: the amount, and the percent
    /// in display units (`1.5` means +1.5%). A zero baseline has no percent.
    func change(from baseline: Double) -> (amount: Double, percent: Double) {
        let amount = value - baseline
        return (amount, baseline != 0 ? amount / baseline * 100 : 0)
    }
}

/// Maps a horizontal cursor position onto the nearest plotted point.
///
/// Positions are fractions of the plot width (`0` = leading edge, `1` =
/// trailing edge), which keeps this independent of any view geometry.
enum ChartScrub {
    /// Selection on the **1-day** chart's real time axis.
    ///
    /// The cursor is converted to a date within `domain`, then snapped to the
    /// nearest point. Mid-session the domain extends past the latest data, so
    /// scrubbing the unfilled remainder clamps to the latest point.
    /// `points` must be in ascending date order. Returns `nil` when empty.
    static func selection(
        atFraction fraction: Double,
        in points: [PortfolioPoint],
        domain: ClosedRange<Date>
    ) -> ChartSelection? {
        guard !points.isEmpty else { return nil }
        let span = domain.upperBound.timeIntervalSince(domain.lowerBound)
        let target = domain.lowerBound.addingTimeInterval(clamped(fraction) * span)
        let index = nearestIndex(to: target, in: points)
        let point = points[index]
        let snapped = span > 0 ? point.date.timeIntervalSince(domain.lowerBound) / span : 0
        return ChartSelection(index: index, date: point.date, value: point.equity, fraction: clamped(snapped))
    }

    /// Selection on a collapsed index axis (every range other than 1-day).
    static func selection(atFraction fraction: Double, in series: ChartSeries) -> ChartSelection? {
        guard let last = series.points.indices.last else { return nil }
        let index = Int((clamped(fraction) * Double(last)).rounded())
        let point = series.points[index]
        let snapped = last > 0 ? Double(index) / Double(last) : 0
        return ChartSelection(index: index, date: point.date, value: point.equity, fraction: snapped)
    }

    /// Timestamp readout for a selected point, as granular as the range's data:
    /// a clock time for 5-minute bars, date + time for hourly bars, and a date
    /// (with the year on long ranges) for daily bars.
    static func timeLabel(for date: Date, range: ChartRange) -> String {
        let time = date.formatted(.dateTime.hour().minute())
        let monthDay = date.formatted(.dateTime.month(.abbreviated).day())
        switch range {
        case .day: return time
        case .week: return "\(monthDay), \(time)"
        case .month, .threeMonths: return monthDay
        case .year, .all: return date.formatted(.dateTime.month(.abbreviated).day().year())
        }
    }

    private static func clamped(_ fraction: Double) -> Double {
        min(max(fraction, 0), 1)
    }

    /// Binary search for the point closest to `target`; ties go to the earlier point.
    private static func nearestIndex(to target: Date, in points: [PortfolioPoint]) -> Int {
        var low = 0
        var high = points.count - 1
        while low < high {
            let mid = (low + high) / 2
            if points[mid].date < target {
                low = mid + 1
            } else {
                high = mid
            }
        }
        // `low` is the first point at or after `target`; its predecessor may be closer.
        guard low > 0 else { return 0 }
        let before = target.timeIntervalSince(points[low - 1].date)
        let after = points[low].date.timeIntervalSince(target)
        return before <= after ? low - 1 : low
    }
}
