import Foundation

/// Snapshot of the Alpaca trading account. Maps `GET /v2/account`.
///
/// Numeric fields arrive as JSON strings, so they are decoded as `String` and
/// exposed as `Double` through computed accessors.
struct Account: Codable, Equatable, Sendable {
    let equityRaw: String
    let lastEquityRaw: String
    let cashRaw: String
    let buyingPowerRaw: String
    let currency: String?

    enum CodingKeys: String, CodingKey {
        case equityRaw = "equity"
        case lastEquityRaw = "last_equity"
        case cashRaw = "cash"
        case buyingPowerRaw = "buying_power"
        case currency
    }

    var equity: Double { Double(equityRaw) ?? 0 }
    var lastEquity: Double { Double(lastEquityRaw) ?? 0 }
    var cash: Double { Double(cashRaw) ?? 0 }
    var buyingPower: Double { Double(buyingPowerRaw) ?? 0 }

    /// Today's change in account currency (`equity - last_equity`).
    var todaysChange: Double { equity - lastEquity }

    /// Today's change as a percentage of the prior trading-day close.
    /// Returns `0` when `last_equity` is zero to avoid divide-by-zero.
    var todaysChangePct: Double {
        guard lastEquity != 0 else { return 0 }
        return (equity - lastEquity) / lastEquity * 100
    }
}
