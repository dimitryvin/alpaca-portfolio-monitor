import Foundation

/// A single point on the equity chart.
struct PortfolioPoint: Identifiable, Equatable, Sendable {
    let date: Date
    let equity: Double
    var id: Date { date }
}

/// Time-series equity data. Maps `GET /v2/account/portfolio/history`.
///
/// Alpaca returns parallel arrays (`timestamp[]`, `equity[]`, ...). Some equity
/// entries can be `null` (e.g. before the account existed); those are skipped.
struct PortfolioHistory: Codable, Equatable, Sendable {
    let timestamp: [Int]
    let equity: [Double?]
    let profitLoss: [Double?]
    let profitLossPct: [Double?]
    let baseValue: Double?
    let timeframe: String?

    enum CodingKeys: String, CodingKey {
        case timestamp
        case equity
        case profitLoss = "profit_loss"
        case profitLossPct = "profit_loss_pct"
        case baseValue = "base_value"
        case timeframe
    }

    /// Pairs valid (non-null) equity values with their timestamps, in order.
    var points: [PortfolioPoint] {
        zip(timestamp, equity).compactMap { ts, eq in
            guard let eq else { return nil }
            return PortfolioPoint(date: Date(timeIntervalSince1970: TimeInterval(ts)), equity: eq)
        }
    }

    /// Overall gain/loss across the series (last valid equity minus base value).
    var overallChange: Double {
        guard let last = points.last?.equity, let base = baseValue, base != 0 else { return 0 }
        return last - base
    }
}
