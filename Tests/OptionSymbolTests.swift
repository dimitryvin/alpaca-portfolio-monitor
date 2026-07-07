import XCTest
@testable import AlpacaPortfolioMonitor

final class OptionSymbolTests: XCTestCase {
    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    func testParsesCall() throws {
        let option = try XCTUnwrap(OptionSymbol("TSLL260710C00014000"))
        XCTAssertEqual(option.underlying, "TSLL")
        XCTAssertEqual(option.kind, .call)
        XCTAssertEqual(option.strike, 14.0, accuracy: 0.0001)

        let components = Self.utc.dateComponents([.year, .month, .day], from: option.expiration)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 10)
    }

    func testParsesPut() throws {
        let option = try XCTUnwrap(OptionSymbol("AAPL240119P00150000"))
        XCTAssertEqual(option.underlying, "AAPL")
        XCTAssertEqual(option.kind, .put)
        XCTAssertEqual(option.strike, 150.0, accuracy: 0.0001)
    }

    func testParsesFractionalStrike() throws {
        let option = try XCTUnwrap(OptionSymbol("F251219C00002500"))
        XCTAssertEqual(option.underlying, "F")
        XCTAssertEqual(option.strike, 2.5, accuracy: 0.0001)
        XCTAssertEqual(option.strikeText, "$2.50")
    }

    func testDisplayHelpers() throws {
        let option = try XCTUnwrap(OptionSymbol("TSLL260710C00014000"))
        XCTAssertEqual(option.strikeText, "$14")           // whole strikes drop cents
        XCTAssertEqual(option.kindLabel, "Call")
        XCTAssertEqual(option.expirationText, "Jul 10")
    }

    func testLowercaseInputIsNormalized() throws {
        let option = try XCTUnwrap(OptionSymbol("rivn260710c00020000"))
        XCTAssertEqual(option.underlying, "RIVN")
        XCTAssertEqual(option.kind, .call)
        XCTAssertEqual(option.strike, 20.0, accuracy: 0.0001)
    }

    func testContractMultiplier() {
        XCTAssertEqual(OptionSymbol.contractMultiplier(for: "TSLL260710C00014000"), 100)
        XCTAssertEqual(OptionSymbol.contractMultiplier(for: "AAPL240119P00150000"), 100)
        XCTAssertEqual(OptionSymbol.contractMultiplier(for: "RIVN"), 1)
        XCTAssertEqual(OptionSymbol.contractMultiplier(for: "AAPL"), 1)
    }

    func testPlainTickersAreNotOptions() {
        for ticker in ["RIVN", "AAPL", "XPEV", "F", ""] {
            XCTAssertNil(OptionSymbol(ticker), "\(ticker) should not parse as an option")
        }
    }

    func testMalformedSymbolsReturnNil() {
        let malformed = [
            "TSLL260710X00014000",  // invalid type char
            "TSLL261710C00014000",  // month 17
            "TSLL260732C00014000",  // day 32
            "TSLL2607C0014000",     // too short suffix
            "260710C00014000",      // missing root
            "TSLL2607X0C00014000",  // non-digit in date
            "TSLL260710C0001400A",  // non-digit in strike
        ]
        for symbol in malformed {
            XCTAssertNil(OptionSymbol(symbol), "\(symbol) should not parse")
        }
    }
}
