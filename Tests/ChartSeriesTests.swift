import XCTest
@testable import AlpacaPortfolioMonitor

final class ChartSeriesTests: XCTestCase {
    private func point(_ interval: TimeInterval, _ equity: Double) -> PortfolioPoint {
        PortfolioPoint(date: Date(timeIntervalSince1970: interval), equity: equity)
    }

    func testAssignsSequentialIndicesCollapsingGaps() {
        // A Friday-close point and a Monday-open point ~2.7 days apart in wall
        // time must sit at adjacent indices, so the weekend gap disappears.
        let friday: TimeInterval = 1_720_468_800   // arbitrary; the gap is what matters
        let monday = friday + 60 * 60 * 65          // ~65 hours later
        let series = ChartSeries(points: [point(friday, 100), point(monday, 101)], range: .week)

        XCTAssertEqual(series.points.map(\.index), [0, 1])
        XCTAssertEqual(series.points.map(\.equity), [100, 101])
        XCTAssertEqual(series.xDomain, 0...1)
    }

    func testTickIndicesAreWithinBoundsDistinctAndSorted() {
        let points = (0..<10).map { point(Double($0) * 3600, Double(100 + $0)) }
        let series = ChartSeries(points: points, range: .month)
        let ticks = series.tickIndices

        XCTAssertFalse(ticks.isEmpty)
        XCTAssertLessThanOrEqual(ticks.count, 4)
        XCTAssertEqual(ticks, ticks.sorted())
        XCTAssertEqual(Array(Set(ticks)).sorted(), ticks) // distinct
        XCTAssertEqual(ticks.first, 0)
        XCTAssertEqual(ticks.last, points.count - 1)
        for tick in ticks { XCTAssertTrue((0..<points.count).contains(tick)) }
    }

    func testLabelIsNonEmptyForValidIndexAndEmptyOutOfRange() {
        let series = ChartSeries(points: [point(0, 1), point(3600, 2)], range: .week)
        XCTAssertFalse(series.label(for: 0).isEmpty)
        XCTAssertFalse(series.label(for: 1).isEmpty)
        XCTAssertEqual(series.label(for: 5), "")
        XCTAssertEqual(series.label(for: -1), "")
    }

    func testEmptySeriesHasValidDomainAndNoTicks() {
        let series = ChartSeries(points: [], range: .year)
        XCTAssertEqual(series.xDomain, 0...1) // still a usable scale
        XCTAssertTrue(series.tickIndices.isEmpty)
    }
}
