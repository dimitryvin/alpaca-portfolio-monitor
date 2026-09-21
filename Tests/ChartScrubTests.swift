import XCTest
@testable import AlpacaPortfolioMonitor

final class ChartScrubTests: XCTestCase {
    private func point(_ interval: TimeInterval, _ equity: Double) -> PortfolioPoint {
        PortfolioPoint(date: Date(timeIntervalSince1970: interval), equity: equity)
    }

    private func date(_ interval: TimeInterval) -> Date { Date(timeIntervalSince1970: interval) }

    // MARK: - Time axis (1D)

    func testTimeAxisPicksNearestPointByDate() {
        let points = [point(0, 100), point(100, 101), point(200, 102)]
        let domain = date(0)...date(400)

        // 0.3 of the domain is t=120, which is nearer to the point at t=100.
        let selection = ChartScrub.selection(atFraction: 0.3, in: points, domain: domain)

        XCTAssertEqual(selection?.index, 1)
        XCTAssertEqual(selection?.date, date(100))
        XCTAssertEqual(selection?.value, 101)
    }

    func testTimeAxisSnapsFractionToTheSelectedPoint() throws {
        let points = [point(0, 100), point(100, 101), point(200, 102)]
        let domain = date(0)...date(400)

        let selection = try XCTUnwrap(ChartScrub.selection(atFraction: 0.3, in: points, domain: domain))

        // The marker sits on the point (t=100 of 400), not under the cursor.
        XCTAssertEqual(selection.fraction, 0.25, accuracy: 0.0001)
    }

    func testTimeAxisClampsToLatestPointInTheUnfilledSession() {
        // Mid-session: data stops at t=200 but the session domain runs to t=400.
        let points = [point(0, 100), point(100, 101), point(200, 102)]
        let domain = date(0)...date(400)

        let selection = ChartScrub.selection(atFraction: 0.9, in: points, domain: domain)

        XCTAssertEqual(selection?.index, 2)
        XCTAssertEqual(selection?.value, 102)
    }

    func testTimeAxisClampsOutOfBoundsFractions() {
        let points = [point(0, 100), point(100, 101), point(200, 102)]
        let domain = date(0)...date(200)

        XCTAssertEqual(ChartScrub.selection(atFraction: -0.5, in: points, domain: domain)?.index, 0)
        XCTAssertEqual(ChartScrub.selection(atFraction: 1.5, in: points, domain: domain)?.index, 2)
    }

    func testTimeAxisMidpointTieResolvesToEarlierPoint() {
        let points = [point(0, 100), point(100, 101)]
        let domain = date(0)...date(100)

        XCTAssertEqual(ChartScrub.selection(atFraction: 0.5, in: points, domain: domain)?.index, 0)
    }

    func testTimeAxisEmptyPointsReturnsNil() {
        XCTAssertNil(ChartScrub.selection(atFraction: 0.5, in: [], domain: date(0)...date(100)))
    }

    func testTimeAxisZeroLengthDomainDoesNotDivideByZero() throws {
        let points = [point(50, 100)]

        let selection = try XCTUnwrap(ChartScrub.selection(atFraction: 0.7, in: points, domain: date(50)...date(50)))

        XCTAssertEqual(selection.index, 0)
        XCTAssertEqual(selection.fraction, 0)
    }

    // MARK: - Index axis (1W and longer)

    func testIndexAxisMapsFractionToNearestIndex() {
        let points = (0..<5).map { point(Double($0) * 3600, Double(100 + $0)) }
        let series = ChartSeries(points: points, range: .week)

        XCTAssertEqual(ChartScrub.selection(atFraction: 0, in: series)?.index, 0)
        XCTAssertEqual(ChartScrub.selection(atFraction: 0.5, in: series)?.index, 2)
        XCTAssertEqual(ChartScrub.selection(atFraction: 0.6, in: series)?.index, 2) // 2.4 rounds down
        XCTAssertEqual(ChartScrub.selection(atFraction: 0.65, in: series)?.index, 3) // 2.6 rounds up
        XCTAssertEqual(ChartScrub.selection(atFraction: 1, in: series)?.index, 4)
    }

    func testIndexAxisCarriesThePointsDateAndValue() throws {
        let points = (0..<5).map { point(Double($0) * 3600, Double(100 + $0)) }
        let series = ChartSeries(points: points, range: .month)

        let selection = try XCTUnwrap(ChartScrub.selection(atFraction: 0.75, in: series))

        XCTAssertEqual(selection.index, 3)
        XCTAssertEqual(selection.date, date(3 * 3600))
        XCTAssertEqual(selection.value, 103)
        XCTAssertEqual(selection.fraction, 0.75, accuracy: 0.0001)
    }

    func testIndexAxisClampsOutOfBoundsFractions() {
        let points = (0..<3).map { point(Double($0), Double($0)) }
        let series = ChartSeries(points: points, range: .year)

        XCTAssertEqual(ChartScrub.selection(atFraction: -1, in: series)?.index, 0)
        XCTAssertEqual(ChartScrub.selection(atFraction: 2, in: series)?.index, 2)
    }

    func testIndexAxisSinglePointAndEmpty() {
        let single = ChartSeries(points: [point(0, 42)], range: .week)
        XCTAssertEqual(ChartScrub.selection(atFraction: 0.8, in: single)?.value, 42)
        XCTAssertEqual(ChartScrub.selection(atFraction: 0.8, in: single)?.fraction, 0)

        XCTAssertNil(ChartScrub.selection(atFraction: 0.5, in: ChartSeries(points: [], range: .week)))
    }

    // MARK: - Readout

    func testTimeLabelGranularityFollowsTheRange() {
        let stamp = date(1_780_000_000)

        let day = ChartScrub.timeLabel(for: stamp, range: .day)
        let week = ChartScrub.timeLabel(for: stamp, range: .week)
        let month = ChartScrub.timeLabel(for: stamp, range: .month)
        let year = ChartScrub.timeLabel(for: stamp, range: .year)

        for label in [day, week, month, year] { XCTAssertFalse(label.isEmpty) }
        // Intraday ranges show a clock time; the hourly week view adds the date.
        XCTAssertTrue(week.contains(day))
        XCTAssertNotEqual(week, day)
        // Daily-bar ranges drop the clock time; long ranges add the year.
        XCTAssertFalse(month.contains(day))
        XCTAssertNotEqual(year, month)
    }

    // MARK: - Change from baseline

    func testChangeFromBaselineReportsAmountAndPercent() {
        let selection = ChartSelection(index: 0, date: date(0), value: 110, fraction: 0)

        let gain = selection.change(from: 100)
        XCTAssertEqual(gain.amount, 10, accuracy: 0.0001)
        XCTAssertEqual(gain.percent, 10, accuracy: 0.0001)

        let loss = selection.change(from: 125)
        XCTAssertEqual(loss.amount, -15, accuracy: 0.0001)
        XCTAssertEqual(loss.percent, -12, accuracy: 0.0001)
    }

    func testChangeFromZeroBaselineHasNoPercent() {
        let selection = ChartSelection(index: 0, date: date(0), value: 50, fraction: 0)

        let change = selection.change(from: 0)

        XCTAssertEqual(change.amount, 50)
        XCTAssertEqual(change.percent, 0)
    }
}
