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
    let unrealizedIntradayPLRaw: String?
    let unrealizedIntradayPLPctRaw: String?
    let changeTodayRaw: String

    enum CodingKeys: String, CodingKey {
        case symbol
        case qtyRaw = "qty"
        case marketValueRaw = "market_value"
        case currentPriceRaw = "current_price"
        case unrealizedPLRaw = "unrealized_pl"
        case unrealizedPLPctRaw = "unrealized_plpc"
        case unrealizedIntradayPLRaw = "unrealized_intraday_pl"
        case unrealizedIntradayPLPctRaw = "unrealized_intraday_plpc"
        case changeTodayRaw = "change_today"
    }

    /// Memberwise initializer with the intraday fields defaulted, so existing
    /// call sites (previews, fixtures) keep compiling without them.
    init(
        symbol: String,
        qtyRaw: String,
        marketValueRaw: String,
        currentPriceRaw: String?,
        unrealizedPLRaw: String,
        unrealizedPLPctRaw: String,
        changeTodayRaw: String,
        unrealizedIntradayPLRaw: String? = nil,
        unrealizedIntradayPLPctRaw: String? = nil
    ) {
        self.symbol = symbol
        self.qtyRaw = qtyRaw
        self.marketValueRaw = marketValueRaw
        self.currentPriceRaw = currentPriceRaw
        self.unrealizedPLRaw = unrealizedPLRaw
        self.unrealizedPLPctRaw = unrealizedPLPctRaw
        self.unrealizedIntradayPLRaw = unrealizedIntradayPLRaw
        self.unrealizedIntradayPLPctRaw = unrealizedIntradayPLPctRaw
        self.changeTodayRaw = changeTodayRaw
    }

    var id: String { symbol }

    var qty: Double { Double(qtyRaw) ?? 0 }
    var marketValue: Double { Double(marketValueRaw) ?? 0 }
    var currentPrice: Double { Double(currentPriceRaw ?? "") ?? 0 }

    /// Unrealized gain/loss on the position since entry.
    var unrealizedPL: Double { Double(unrealizedPLRaw) ?? 0 }

    /// Unrealized P/L as a fraction (Alpaca returns e.g. "0.0123" for 1.23%).
    var unrealizedPLPct: Double { (Double(unrealizedPLPctRaw) ?? 0) * 100 }

    /// Today's unrealized P/L in dollars (Alpaca `unrealized_intraday_pl`). When
    /// the field is absent it is derived from `change_today`: today's dollar move
    /// is `marketValue − marketValue / (1 + changeToday)`.
    var unrealizedIntradayPL: Double {
        if let raw = unrealizedIntradayPLRaw, let value = Double(raw) { return value }
        let change = Double(changeTodayRaw) ?? 0
        guard change != -1 else { return 0 }
        return marketValue - marketValue / (1 + change)
    }

    /// Today's unrealized P/L as a percentage (Alpaca `unrealized_intraday_plpc`).
    /// Falls back to `change_today` when the field is absent.
    var unrealizedIntradayPLPct: Double {
        if let raw = unrealizedIntradayPLPctRaw, let value = Double(raw) { return value * 100 }
        return (Double(changeTodayRaw) ?? 0) * 100
    }

    /// Today's price change as a fraction; exposed as a percentage.
    var changeTodayPct: Double { (Double(changeTodayRaw) ?? 0) * 100 }

    /// The ticker shown to the user: the underlying for options, else the raw symbol.
    var displaySymbol: String { OptionSymbol(symbol)?.underlying ?? symbol }
}
