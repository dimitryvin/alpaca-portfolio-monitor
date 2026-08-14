import XCTest
@testable import AlpacaPortfolioMonitor

final class ParsingTests: XCTestCase {
    func testDecodeAccount() throws {
        let json = """
        {
          "equity": "12345.67",
          "last_equity": "12197.00",
          "cash": "500.25",
          "buying_power": "1000.50",
          "currency": "USD"
        }
        """.data(using: .utf8)!

        let account = try JSONDecoder().decode(Account.self, from: json)
        XCTAssertEqual(account.equity, 12345.67, accuracy: 0.001)
        XCTAssertEqual(account.lastEquity, 12197.00, accuracy: 0.001)
        XCTAssertEqual(account.cash, 500.25, accuracy: 0.001)
        XCTAssertEqual(account.buyingPower, 1000.50, accuracy: 0.001)
    }

    func testDecodePortfolioHistoryWithNulls() throws {
        let json = """
        {
          "timestamp": [1700000000, 1700000300, 1700000600],
          "equity": [null, 100.0, 110.0],
          "profit_loss": [null, 0.0, 10.0],
          "profit_loss_pct": [null, 0.0, 0.1],
          "base_value": 100.0,
          "timeframe": "5Min"
        }
        """.data(using: .utf8)!

        let history = try JSONDecoder().decode(PortfolioHistory.self, from: json)
        // The leading null equity should be dropped.
        XCTAssertEqual(history.points.count, 2)
        XCTAssertEqual(history.points.first?.equity, 100.0)
        XCTAssertEqual(history.points.last?.equity, 110.0)
    }

    func testDecodePositions() throws {
        let json = """
        [
          {
            "symbol": "AAPL",
            "qty": "10",
            "market_value": "1900.00",
            "current_price": "190.00",
            "unrealized_pl": "100.00",
            "unrealized_plpc": "0.0555",
            "change_today": "0.012"
          }
        ]
        """.data(using: .utf8)!

        let positions = try JSONDecoder().decode([Position].self, from: json)
        XCTAssertEqual(positions.count, 1)
        let p = positions[0]
        XCTAssertEqual(p.symbol, "AAPL")
        XCTAssertEqual(p.qty, 10)
        XCTAssertEqual(p.marketValue, 1900.0, accuracy: 0.001)
        XCTAssertEqual(p.unrealizedPLPct, 5.55, accuracy: 0.001)
        XCTAssertEqual(p.changeTodayPct, 1.2, accuracy: 0.001)
    }

    func testDecodePositionUsesIntradayFieldsWhenPresent() throws {
        let json = """
        [
          {
            "symbol": "AAPL",
            "qty": "10",
            "market_value": "1900.00",
            "current_price": "190.00",
            "unrealized_pl": "100.00",
            "unrealized_plpc": "0.0555",
            "unrealized_intraday_pl": "22.50",
            "unrealized_intraday_plpc": "0.0118",
            "change_today": "0.012"
          }
        ]
        """.data(using: .utf8)!

        let p = try JSONDecoder().decode([Position].self, from: json)[0]
        XCTAssertEqual(p.unrealizedIntradayPL, 22.50, accuracy: 0.001)
        XCTAssertEqual(p.unrealizedIntradayPLPct, 1.18, accuracy: 0.001)
    }

    func testDecodePositionFallsBackToChangeTodayWhenIntradayAbsent() throws {
        // Legacy payload without the intraday keys must still decode, deriving
        // today's P/L from change_today rather than failing.
        let json = """
        [
          {
            "symbol": "AAPL",
            "qty": "10",
            "market_value": "1012.00",
            "current_price": "101.20",
            "unrealized_pl": "100.00",
            "unrealized_plpc": "0.0555",
            "change_today": "0.012"
          }
        ]
        """.data(using: .utf8)!

        let p = try JSONDecoder().decode([Position].self, from: json)[0]
        // Percentage falls back to change_today (1.2%).
        XCTAssertEqual(p.unrealizedIntradayPLPct, 1.2, accuracy: 0.001)
        // Dollars derive from marketValue − marketValue / (1 + changeToday).
        XCTAssertEqual(p.unrealizedIntradayPL, 1012.0 - 1012.0 / 1.012, accuracy: 0.001)
    }
}
