import Foundation

/// Computes the X-axis domain for the equity chart.
enum ChartDomain {
    /// US regular trading session in Eastern Time.
    private static let sessionOpen = DateComponents(hour: 9, minute: 30)
    private static let sessionClose = DateComponents(hour: 16)

    /// X-axis domain for the given points and range.
    ///
    /// For the **1-day** range this spans the full regular trading session
    /// (9:30–16:00 ET) so the line ends at the current time of day instead of
    /// stretching to the right edge (à la Robinhood). Points outside regular
    /// hours (extended-hours data) widen the domain so they're never clipped.
    ///
    /// Other ranges use the data's own extent. Returns `nil` when empty.
    static func x(for points: [PortfolioPoint], range: ChartRange) -> ClosedRange<Date>? {
        guard let first = points.first?.date, let last = points.last?.date else { return nil }
        guard range == .day else { return first...last }

        var calendar = Calendar(identifier: .gregorian)
        if let eastern = TimeZone(identifier: "America/New_York") {
            calendar.timeZone = eastern
        }
        // Anchor the session to the trading day of the first point.
        let midnight = calendar.startOfDay(for: first)
        let open = calendar.date(byAdding: sessionOpen, to: midnight) ?? first
        let close = calendar.date(byAdding: sessionClose, to: midnight) ?? last
        return min(open, first)...max(close, last)
    }
}
