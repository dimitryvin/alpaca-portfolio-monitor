import XCTest
@testable import AlpacaPortfolioMonitor

@MainActor
final class TradeNotifierTests: XCTestCase {
    private func trade(
        isBuy: Bool,
        qty: Double = 10,
        price: Double = 150,
        realizedPL: Double? = nil,
        realizedPLPct: Double? = nil
    ) -> Trade {
        Trade(
            id: "1", symbol: "AAPL", isBuy: isBuy, qty: qty, price: price,
            date: .distantPast, realizedPL: realizedPL, realizedPLPct: realizedPLPct
        )
    }

    func testBuyBodyHasNoRealizedPL() {
        let body = TradeNotifier.body(for: trade(isBuy: true, qty: 5, price: 145))
        XCTAssertEqual(body, "5 @ $145.00")
    }

    func testSellBodyIncludesRealizedGain() {
        let body = TradeNotifier.body(
            for: trade(isBuy: false, qty: 10, price: 150, realizedPL: 120, realizedPLPct: 8.7)
        )
        XCTAssertEqual(body, "10 @ $150.00 · Realized P/L +$120.00 (+8.70%)")
    }

    func testSellBodyIncludesRealizedLoss() {
        let body = TradeNotifier.body(
            for: trade(isBuy: false, qty: 4, price: 40, realizedPL: -40, realizedPLPct: -10)
        )
        XCTAssertEqual(body, "4 @ $40.00 · Realized P/L -$40.00 (-10.00%)")
    }

    func testSellWithoutCostBasisOmitsRealizedPL() {
        let body = TradeNotifier.body(for: trade(isBuy: false, qty: 2, price: 30))
        XCTAssertEqual(body, "2 @ $30.00")
    }

    func testFractionalQuantityIsFormatted() {
        let body = TradeNotifier.body(for: trade(isBuy: true, qty: 1.5, price: 100))
        XCTAssertEqual(body, "1.5000 @ $100.00")
    }
}
