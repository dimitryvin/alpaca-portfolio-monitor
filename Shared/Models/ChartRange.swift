import Foundation

/// Selectable chart ranges, each mapping to Alpaca's `period`/`timeframe` query
/// parameters for `GET /v2/account/portfolio/history`.
enum ChartRange: String, CaseIterable, Identifiable, Sendable {
    case day = "1D"
    case week = "1W"
    case month = "1M"
    case threeMonths = "3M"
    case year = "1Y"
    case all = "All"

    var id: String { rawValue }

    /// Display label used in the range picker.
    var label: String { rawValue }

    /// Alpaca `period` parameter.
    var period: String {
        switch self {
        case .day: return "1D"
        case .week: return "1W"
        case .month: return "1M"
        case .threeMonths: return "3M"
        case .year: return "1A"
        case .all: return "all"
        }
    }

    /// Alpaca `timeframe` parameter, chosen for a reasonable point density.
    var timeframe: String {
        switch self {
        case .day: return "5Min"
        case .week: return "1H"
        case .month, .threeMonths, .year, .all: return "1D"
        }
    }

    // MARK: - Market-data bars

    /// `timeframe` parameter for the Market Data bars endpoint
    /// (`GET /v2/stocks/{symbol}/bars`). Uses the API's canonical unit spellings
    /// (`Min`/`Hour`/`Day`), which differ from portfolio-history's `timeframe`.
    var barTimeframe: String {
        switch self {
        case .day: return "5Min"
        case .week: return "1Hour"
        case .month, .threeMonths, .year, .all: return "1Day"
        }
    }

    /// The `start` timestamp for a bars request, measured back from `now`, giving
    /// each range a sensible lookback window.
    func barStart(from now: Date) -> Date {
        let day: TimeInterval = 86_400
        let lookback: TimeInterval
        switch self {
        case .day: lookback = day
        case .week: lookback = 7 * day
        case .month: lookback = 31 * day
        case .threeMonths: lookback = 93 * day
        case .year: lookback = 366 * day
        case .all: lookback = 1_825 * day // ~5y; IEX history reaches back further than most accounts hold
        }
        return now.addingTimeInterval(-lookback)
    }
}
