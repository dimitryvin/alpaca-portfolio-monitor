import XCTest
@testable import AlpacaPortfolioMonitor

final class PositionSortTests: XCTestCase {
    private func position(
        symbol: String,
        marketValue: String = "100",
        totalPL: String,
        intradayPL: String
    ) -> Position {
        Position(
            symbol: symbol,
            qtyRaw: "1",
            marketValueRaw: marketValue,
            currentPriceRaw: marketValue,
            unrealizedPLRaw: totalPL,
            unrealizedPLPctRaw: "0",
            changeTodayRaw: "0",
            unrealizedIntradayPLRaw: intradayPL,
            unrealizedIntradayPLPctRaw: "0"
        )
    }

    private lazy var positions: [Position] = [
        position(symbol: "MU", totalPL: "6.15", intradayPL: "-1.00"),
        position(symbol: "AMD", totalPL: "-8.03", intradayPL: "3.00"),
        position(symbol: "NVDA", totalPL: "12.83", intradayPL: "0.50"),
    ]

    func testSortByTotalPLDescending() {
        let result = positions.sorted(by: .totalPL, ascending: false).map(\.symbol)
        XCTAssertEqual(result, ["NVDA", "MU", "AMD"])
    }

    func testSortByTotalPLAscending() {
        let result = positions.sorted(by: .totalPL, ascending: true).map(\.symbol)
        XCTAssertEqual(result, ["AMD", "MU", "NVDA"])
    }

    func testSortByTodayPLDescending() {
        let result = positions.sorted(by: .todayPL, ascending: false).map(\.symbol)
        XCTAssertEqual(result, ["AMD", "NVDA", "MU"])
    }

    func testSortByNameAscending() {
        let result = positions.sorted(by: .name, ascending: true).map(\.symbol)
        XCTAssertEqual(result, ["AMD", "MU", "NVDA"])
    }

    func testSortByNameUsesUnderlyingForOptions() {
        // An AAPL call option should sort under "A", not its raw OCC symbol.
        let option = position(symbol: "AAPL260116C00150000", totalPL: "0", intradayPL: "0")
        let zebra = position(symbol: "ZM", totalPL: "0", intradayPL: "0")
        let result = [zebra, option].sorted(by: .name, ascending: true).map(\.displaySymbol)
        XCTAssertEqual(result, ["AAPL", "ZM"])
    }

    func testDefaultDirections() {
        XCTAssertFalse(PositionSortKey.totalPL.defaultAscending)
        XCTAssertFalse(PositionSortKey.todayPL.defaultAscending)
        XCTAssertTrue(PositionSortKey.name.defaultAscending)
    }

    func testPLColumnSelectsMatchingFigures() {
        let p = position(symbol: "MU", totalPL: "6.15", intradayPL: "-1.00")
        XCTAssertEqual(PLColumn.total.value(for: p), 6.15, accuracy: 0.001)
        XCTAssertEqual(PLColumn.today.value(for: p), -1.00, accuracy: 0.001)
    }
}
