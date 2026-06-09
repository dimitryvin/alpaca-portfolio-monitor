import XCTest
@testable import AlpacaPortfolioMonitor

final class ChartDomainTests: XCTestCase {
    private let etCal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()

    private func et(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        etCal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    func testDayDomainSpansRegularSession() {
        // Data ends mid-morning, but the domain should still reach the close.
        let points = [
            PortfolioPoint(date: et(2026, 6, 9, 9, 30), equity: 100),
            PortfolioPoint(date: et(2026, 6, 9, 11, 0), equity: 101),
        ]
        let domain = ChartDomain.x(for: points, range: .day)
        XCTAssertEqual(domain?.lowerBound, et(2026, 6, 9, 9, 30))
        XCTAssertEqual(domain?.upperBound, et(2026, 6, 9, 16, 0))
    }

    func testDayDomainNotClippedByExtendedHours() {
        let points = [
            PortfolioPoint(date: et(2026, 6, 9, 8, 0), equity: 100),  // pre-market
            PortfolioPoint(date: et(2026, 6, 9, 17, 0), equity: 101), // post-market
        ]
        let domain = ChartDomain.x(for: points, range: .day)
        XCTAssertEqual(domain?.lowerBound, et(2026, 6, 9, 8, 0))
        XCTAssertEqual(domain?.upperBound, et(2026, 6, 9, 17, 0))
    }

    func testNonDayRangeUsesDataExtent() {
        let first = et(2026, 5, 1, 9, 30)
        let last = et(2026, 6, 9, 16, 0)
        let points = [
            PortfolioPoint(date: first, equity: 1),
            PortfolioPoint(date: last, equity: 2),
        ]
        let domain = ChartDomain.x(for: points, range: .month)
        XCTAssertEqual(domain?.lowerBound, first)
        XCTAssertEqual(domain?.upperBound, last)
    }

    func testEmptyReturnsNil() {
        XCTAssertNil(ChartDomain.x(for: [], range: .day))
    }
}
