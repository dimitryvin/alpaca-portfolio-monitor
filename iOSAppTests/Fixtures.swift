import Foundation
@testable import AlpacaMonitorMobile

/// Shared sample values for the feature tests.
enum Fixtures {
    static let credentials = Credentials(keyID: "key-id", secret: "secret-key")

    static let account = Account(
        equityRaw: "10500.00",
        lastEquityRaw: "10000.00",
        cashRaw: "2500.00",
        buyingPowerRaw: "5000.00",
        currency: "USD"
    )

    static let history = PortfolioHistory(
        timestamp: [1_720_000_000, 1_720_001_800, 1_720_003_600],
        equity: [10000, 10250, 10500],
        profitLoss: [0, 250, 500],
        profitLossPct: [0, 0.025, 0.05],
        baseValue: 10000,
        timeframe: "5Min"
    )

    static let positions = [
        Position(
            symbol: "AAPL", qtyRaw: "10", marketValueRaw: "2300.00",
            currentPriceRaw: "230.00", unrealizedPLRaw: "150.00",
            unrealizedPLPctRaw: "0.0699", changeTodayRaw: "0.0120"
        )
    ]

    /// Two sells with realized P/L (100 + 50 = 150) and one buy without.
    static let trades = [
        Trade(id: "3", symbol: "AAPL", isBuy: false, qty: 5, price: 230,
              date: Date(timeIntervalSince1970: 1_720_003_600),
              realizedPL: 100, realizedPLPct: 5),
        Trade(id: "2", symbol: "MSFT", isBuy: false, qty: 2, price: 410,
              date: Date(timeIntervalSince1970: 1_720_002_600),
              realizedPL: 50, realizedPLPct: 2),
        Trade(id: "1", symbol: "AAPL", isBuy: true, qty: 10, price: 215,
              date: Date(timeIntervalSince1970: 1_720_000_600),
              realizedPL: nil, realizedPLPct: nil),
    ]
}
