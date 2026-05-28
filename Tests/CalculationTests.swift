import XCTest
@testable import AlpacaPortfolioMonitor

final class CalculationTests: XCTestCase {
    private func account(equity: String, lastEquity: String) -> Account {
        Account(
            equityRaw: equity,
            lastEquityRaw: lastEquity,
            cashRaw: "0",
            buyingPowerRaw: "0",
            currency: "USD"
        )
    }

    func testTodaysChangePositive() {
        let a = account(equity: "110", lastEquity: "100")
        XCTAssertEqual(a.todaysChange, 10, accuracy: 0.001)
        XCTAssertEqual(a.todaysChangePct, 10, accuracy: 0.001)
    }

    func testTodaysChangeNegative() {
        let a = account(equity: "90", lastEquity: "100")
        XCTAssertEqual(a.todaysChange, -10, accuracy: 0.001)
        XCTAssertEqual(a.todaysChangePct, -10, accuracy: 0.001)
    }

    func testTodaysChangePctZeroLastEquityIsSafe() {
        let a = account(equity: "100", lastEquity: "0")
        XCTAssertEqual(a.todaysChangePct, 0, accuracy: 0.001)
    }

    func testChartRangeMapping() {
        XCTAssertEqual(ChartRange.day.period, "1D")
        XCTAssertEqual(ChartRange.day.timeframe, "5Min")
        XCTAssertEqual(ChartRange.year.period, "1A")
        XCTAssertEqual(ChartRange.all.period, "all")
        XCTAssertEqual(ChartRange.month.timeframe, "1D")
    }

    func testOverallChange() {
        let history = PortfolioHistory(
            timestamp: [1, 2, 3],
            equity: [100, 105, 120],
            profitLoss: [0, 5, 20],
            profitLossPct: [0, 0.05, 0.2],
            baseValue: 100,
            timeframe: "1D"
        )
        XCTAssertEqual(history.overallChange, 20, accuracy: 0.001)
        XCTAssertEqual(history.points.count, 3)
    }

    func testSignedCurrencyFormatting() {
        XCTAssertTrue(CurrencyFormatter.full.signedString(from: 148).hasPrefix("+"))
        XCTAssertTrue(CurrencyFormatter.full.signedString(from: -148).hasPrefix("-"))
    }

    func testSignedPercentFormatting() {
        XCTAssertEqual(PercentFormatter.signed(1.23), "+1.23%")
        XCTAssertEqual(PercentFormatter.signed(-1.23), "-1.23%")
        XCTAssertEqual(PercentFormatter.signed(0), "0.00%")
    }
}
