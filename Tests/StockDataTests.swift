import XCTest
@testable import AlpacaPortfolioMonitor

final class StockDataTests: XCTestCase {
    // MARK: - Asset decoding

    func testAssetDecodesClassKey() throws {
        let json = """
        {
            "id": "b0b6dd9d-8b9b-48a9-ba46-b9d54906e415",
            "class": "us_equity",
            "exchange": "NASDAQ",
            "symbol": "AAPL",
            "name": "Apple Inc. Common Stock",
            "status": "active",
            "tradable": true,
            "fractionable": true,
            "shortable": true,
            "marginable": true
        }
        """.data(using: .utf8)!

        let asset = try JSONDecoder().decode(Asset.self, from: json)
        XCTAssertEqual(asset.symbol, "AAPL")
        XCTAssertEqual(asset.name, "Apple Inc. Common Stock")
        XCTAssertEqual(asset.assetClass, "us_equity")
        XCTAssertEqual(asset.exchange, "NASDAQ")
        XCTAssertEqual(asset.tradable, true)
        XCTAssertEqual(asset.fractionable, true)
    }

    // MARK: - Bars decoding + points mapping

    func testBarsResponseDecodesAndMapsToPoints() throws {
        let json = """
        {
            "bars": [
                { "t": "2024-07-01T13:30:00Z", "o": 226.0, "h": 227.2, "l": 225.5, "c": 226.5, "v": 1000, "n": 8, "vw": 226.4 },
                { "t": "2024-07-01T13:35:00Z", "o": 226.5, "h": 228.0, "l": 226.1, "c": 227.8, "v": 1200, "n": 9, "vw": 227.1 }
            ],
            "symbol": "AAPL",
            "next_page_token": null
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(StockBarsResponse.self, from: json)
        let bars = try XCTUnwrap(response.bars)
        XCTAssertEqual(bars.count, 2)
        XCTAssertEqual(bars[0].close, 226.5, accuracy: 0.0001)

        let points = bars.points
        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points[0].equity, 226.5, accuracy: 0.0001)
        XCTAssertEqual(points[1].equity, 227.8, accuracy: 0.0001)
        // 2024-07-01T13:30:00Z
        XCTAssertEqual(points[0].date.timeIntervalSince1970, 1_719_840_600, accuracy: 1)
    }

    func testBarParsesFractionalSecondTimestamp() {
        let bar = StockBar(
            timestampRaw: "2024-07-01T13:30:00.123Z",
            open: 1, high: 1, low: 1, close: 1, volume: 1
        )
        XCTAssertNotNil(bar.date)
    }

    func testBarWithUnparseableTimestampIsDroppedFromPoints() {
        let bars = [
            StockBar(timestampRaw: "not-a-date", open: 1, high: 1, low: 1, close: 1, volume: 1),
            StockBar(timestampRaw: "2024-07-01T13:30:00Z", open: 2, high: 2, low: 2, close: 2, volume: 2),
        ]
        XCTAssertEqual(bars.points.count, 1)
        XCTAssertEqual(bars.points[0].equity, 2, accuracy: 0.0001)
    }

    // MARK: - ChartRange bars mapping

    func testChartRangeBarTimeframes() {
        XCTAssertEqual(ChartRange.day.barTimeframe, "5Min")
        XCTAssertEqual(ChartRange.week.barTimeframe, "1Hour")
        XCTAssertEqual(ChartRange.month.barTimeframe, "1Day")
        XCTAssertEqual(ChartRange.year.barTimeframe, "1Day")
        XCTAssertEqual(ChartRange.all.barTimeframe, "1Day")
    }

    func testChartRangeBarStartLooksBack() {
        let now = Date(timeIntervalSince1970: 1_720_000_000)
        XCTAssertEqual(ChartRange.day.barStart(from: now), now.addingTimeInterval(-86_400))
        XCTAssertEqual(ChartRange.week.barStart(from: now), now.addingTimeInterval(-7 * 86_400))
        // Longer ranges look further back than shorter ones.
        XCTAssertLessThan(ChartRange.year.barStart(from: now), ChartRange.month.barStart(from: now))
        XCTAssertLessThan(ChartRange.all.barStart(from: now), ChartRange.year.barStart(from: now))
    }
}
