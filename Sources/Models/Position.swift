import Foundation

/// An open position. Maps an element of `GET /v2/positions`.
///
/// Numeric fields arrive as JSON strings and are exposed as `Double`.
struct Position: Codable, Equatable, Sendable, Identifiable {
    let symbol: String
    let qtyRaw: String
    let marketValueRaw: String
    let currentPriceRaw: String?
    let unrealizedPLRaw: String
    let unrealizedPLPctRaw: String
    let changeTodayRaw: String

    enum CodingKeys: String, CodingKey {
        case symbol
        case qtyRaw = "qty"
        case marketValueRaw = "market_value"
        case currentPriceRaw = "current_price"
        case unrealizedPLRaw = "unrealized_pl"
        case unrealizedPLPctRaw = "unrealized_plpc"
        case changeTodayRaw = "change_today"
    }

    var id: String { symbol }

    var qty: Double { Double(qtyRaw) ?? 0 }
    var marketValue: Double { Double(marketValueRaw) ?? 0 }
    var currentPrice: Double { Double(currentPriceRaw ?? "") ?? 0 }
    var unrealizedPL: Double { Double(unrealizedPLRaw) ?? 0 }

    /// Unrealized P/L as a fraction (Alpaca returns e.g. "0.0123" for 1.23%).
    var unrealizedPLPct: Double { (Double(unrealizedPLPctRaw) ?? 0) * 100 }

    /// Today's price change as a fraction; exposed as a percentage.
    var changeTodayPct: Double { (Double(changeTodayRaw) ?? 0) * 100 }
}
