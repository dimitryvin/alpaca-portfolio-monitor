import ComposableArchitecture
import Foundation

extension AlpacaAPIClient {
    /// Canned data so SwiftUI previews render a populated dashboard without a network.
    static let preview = AlpacaAPIClient(
        account: { _ in Sample.account },
        history: { _, _ in Sample.history },
        positions: { _ in Sample.positions },
        trades: { _ in Sample.trades },
        asset: { _, symbol in Sample.asset(for: symbol) },
        bars: { _, _, _ in Sample.bars }
    )

    static let previewValue = AlpacaAPIClient.preview
}

private enum Sample {
    static let account = Account(
        equityRaw: "128450.72",
        lastEquityRaw: "126910.10",
        cashRaw: "14210.55",
        buyingPowerRaw: "28421.10",
        currency: "USD"
    )

    static let history: PortfolioHistory = {
        let base = 1_720_000_000 // fixed epoch so previews are deterministic
        let equities: [Double] = [
            126910, 127100, 126880, 127400, 127950, 127600, 128200, 128700, 128300, 128450,
        ]
        return PortfolioHistory(
            timestamp: equities.indices.map { base + $0 * 1800 },
            equity: equities.map { Optional($0) },
            profitLoss: equities.map { $0 - 126910 },
            profitLossPct: equities.map { ($0 - 126910) / 126910 },
            baseValue: 126910,
            timeframe: "5Min"
        )
    }()

    static let positions = [
        Position(
            symbol: "AAPL", qtyRaw: "40", marketValueRaw: "9240.00",
            currentPriceRaw: "231.00", unrealizedPLRaw: "612.40",
            unrealizedPLPctRaw: "0.0709", changeTodayRaw: "0.0123",
            avgEntryPriceRaw: "215.69", costBasisRaw: "8627.60",
            assetClass: "us_equity", exchange: "NASDAQ"
        ),
        Position(
            symbol: "NVDA", qtyRaw: "20", marketValueRaw: "24800.00",
            currentPriceRaw: "1240.00", unrealizedPLRaw: "-320.10",
            unrealizedPLPctRaw: "-0.0127", changeTodayRaw: "-0.0044",
            avgEntryPriceRaw: "1256.00", costBasisRaw: "25120.10",
            assetClass: "us_equity", exchange: "NASDAQ"
        ),
    ]

    static func asset(for symbol: String) -> Asset {
        let names = [
            "AAPL": "Apple Inc. Common Stock",
            "NVDA": "NVIDIA Corporation Common Stock",
            "TSLL": "Direxion Daily TSLA Bull 2X Shares",
        ]
        return Asset(
            symbol: symbol,
            name: names[symbol] ?? "\(symbol) Common Stock",
            exchange: "NASDAQ",
            assetClass: "us_equity",
            tradable: true,
            fractionable: true,
            shortable: true,
            marginable: true,
            status: "active"
        )
    }

    static let bars: [StockBar] = {
        let closes: [Double] = [
            226.1, 227.4, 226.9, 228.8, 230.2, 229.6, 231.5, 232.0, 230.9, 231.0,
        ]
        return closes.enumerated().map { offset, close in
            StockBar(
                timestampRaw: "2024-07-\(String(format: "%02d", offset + 1))T14:30:00Z",
                open: close - 0.4, high: close + 0.6, low: close - 0.7,
                close: close, volume: 1_000_000
            )
        }
    }()

    static let trades = [
        Trade(
            id: "3", symbol: "NVDA", isBuy: false, qty: 5, price: 1240,
            date: Date(timeIntervalSince1970: 1_720_003_600),
            realizedPL: 420.5, realizedPLPct: 7.3
        ),
        Trade(
            id: "2", symbol: "AAPL", isBuy: true, qty: 40, price: 215.7,
            date: Date(timeIntervalSince1970: 1_719_903_600),
            realizedPL: nil, realizedPLPct: nil
        ),
        Trade(
            id: "1", symbol: "TSLL260710C00014000", isBuy: true, qty: 3, price: 1.85,
            date: Date(timeIntervalSince1970: 1_719_803_600),
            realizedPL: nil, realizedPLPct: nil
        ),
    ]
}
