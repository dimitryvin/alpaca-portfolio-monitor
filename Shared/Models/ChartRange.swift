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
}
