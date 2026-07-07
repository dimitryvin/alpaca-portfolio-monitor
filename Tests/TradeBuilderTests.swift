import XCTest
@testable import AlpacaPortfolioMonitor

final class TradeBuilderTests: XCTestCase {
    private func fill(_ id: String, _ symbol: String, _ side: String, _ qty: String, _ price: String, _ time: String) -> Activity {
        Activity(id: id, symbol: symbol, side: side, qtyRaw: qty, priceRaw: price, transactionTime: time, type: "fill")
    }

    func testAverageCostRealizedPL() {
        // Buy 10 @ 100, buy 10 @ 200 → avg cost 150. Sell 5 @ 180 → +30 * 5 = +150.
        let activities = [
            fill("1", "AAA", "buy", "10", "100", "2026-01-01T10:00:00Z"),
            fill("2", "AAA", "buy", "10", "200", "2026-01-02T10:00:00Z"),
            fill("3", "AAA", "sell", "5", "180", "2026-01-03T10:00:00Z"),
        ]
        let trades = TradeBuilder.build(from: activities)
        // Most-recent first → the sell is first.
        let sell = trades.first
        XCTAssertEqual(sell?.id, "3")
        XCTAssertEqual(sell?.isBuy, false)
        XCTAssertEqual(sell?.realizedPL ?? .nan, 150, accuracy: 0.0001)
        XCTAssertEqual(sell?.realizedPLPct ?? .nan, 20, accuracy: 0.0001) // (180-150)/150
    }

    func testLossAndTotalRealized() {
        let activities = [
            fill("1", "BBB", "buy", "4", "50", "2026-01-01T10:00:00Z"),
            fill("2", "BBB", "sell", "4", "40", "2026-01-02T10:00:00Z"), // -40
        ]
        let trades = TradeBuilder.build(from: activities)
        XCTAssertEqual(trades.first?.realizedPL ?? .nan, -40, accuracy: 0.0001)
        XCTAssertEqual(trades.compactMap(\.realizedPL).reduce(0, +), -40, accuracy: 0.0001)
    }

    func testOptionRealizedPLUsesContractMultiplier() {
        // 1 contract = 100 shares. Bought @ 0.44, sold @ 0.23 → per-share -0.21,
        // scaled ×100 → -$21.00. Percentage is unaffected by the multiplier.
        let activities = [
            fill("1", "TSLL260710C00014000", "buy", "1", "0.44", "2026-01-01T10:00:00Z"),
            fill("2", "TSLL260710C00014000", "sell", "1", "0.23", "2026-01-02T10:00:00Z"),
        ]
        let trades = TradeBuilder.build(from: activities)
        XCTAssertEqual(trades.first?.realizedPL ?? .nan, -21.0, accuracy: 0.0001)
        XCTAssertEqual(trades.first?.realizedPLPct ?? .nan, -47.7273, accuracy: 0.001)
        // Buy value also reflects the 100-share contract (1 × 0.44 × 100).
        XCTAssertEqual(trades.last?.value ?? .nan, 44.0, accuracy: 0.0001)
    }

    func testStockValueHasNoMultiplier() {
        let trades = TradeBuilder.build(from: [
            fill("1", "RIVN", "buy", "9", "17.75", "2026-01-01T10:00:00Z"),
        ])
        XCTAssertEqual(trades.first?.value ?? .nan, 159.75, accuracy: 0.0001) // 9 × 17.75 × 1
    }

    func testBuysHaveNoRealizedPL() {
        let trades = TradeBuilder.build(from: [
            fill("1", "CCC", "buy", "1", "10", "2026-01-01T10:00:00Z"),
        ])
        XCTAssertNil(trades.first?.realizedPL)
    }

    func testSellWithoutCostBasisHasNoPL() {
        // Sell with no prior buy → no cost basis → nil P/L.
        let trades = TradeBuilder.build(from: [
            fill("1", "DDD", "sell", "2", "30", "2026-01-01T10:00:00Z"),
        ])
        XCTAssertEqual(trades.first?.isBuy, false)
        XCTAssertNil(trades.first?.realizedPL)
    }

    func testOrderingIsMostRecentFirst() {
        let trades = TradeBuilder.build(from: [
            fill("1", "EEE", "buy", "1", "10", "2026-01-01T10:00:00Z"),
            fill("2", "EEE", "buy", "1", "11", "2026-01-03T10:00:00Z"),
            fill("3", "EEE", "buy", "1", "12", "2026-01-02T10:00:00Z"),
        ])
        XCTAssertEqual(trades.map(\.id), ["2", "3", "1"])
    }
}
