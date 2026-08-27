import Foundation

/// A single OHLCV price bar. Maps an element of the `bars` array from the Alpaca
/// Market Data API `GET /v2/stocks/{symbol}/bars`.
///
/// The timestamp `t` arrives as an RFC-3339 string (e.g. `2024-01-03T14:30:00Z`),
/// optionally with fractional seconds; both forms are parsed.
struct StockBar: Codable, Equatable, Sendable {
    let timestampRaw: String
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double

    enum CodingKeys: String, CodingKey {
        case timestampRaw = "t"
        case open = "o"
        case high = "h"
        case low = "l"
        case close = "c"
        case volume = "v"
    }

    init(
        timestampRaw: String,
        open: Double,
        high: Double,
        low: Double,
        close: Double,
        volume: Double
    ) {
        self.timestampRaw = timestampRaw
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
    }

    /// The bar's timestamp, or `nil` if the RFC-3339 string can't be parsed.
    var date: Date? { Self.parse(timestampRaw) }

    // ISO-8601 parsers: one with fractional seconds, one without. Kept static so
    // they aren't re-created per bar (formatters are relatively expensive). They
    // are only ever read (`.date(from:)`), which is safe to share.
    nonisolated(unsafe) private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) private static let plain = ISO8601DateFormatter()

    private static func parse(_ raw: String) -> Date? {
        fractional.date(from: raw) ?? plain.date(from: raw)
    }
}

/// The envelope returned by `GET /v2/stocks/{symbol}/bars`.
struct StockBarsResponse: Codable, Equatable, Sendable {
    let bars: [StockBar]?
    let symbol: String?
}

extension Array where Element == StockBar {
    /// Maps bars to chart points (close price over time), dropping any bar whose
    /// timestamp fails to parse. Reuses the equity chart's `PortfolioPoint`.
    var points: [PortfolioPoint] {
        compactMap { bar in
            guard let date = bar.date else { return nil }
            return PortfolioPoint(date: date, equity: bar.close)
        }
    }
}
