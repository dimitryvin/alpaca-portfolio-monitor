import Foundation

/// How the positions list is ordered.
enum PositionSortKey: String, CaseIterable, Identifiable, Sendable {
    case totalPL
    case todayPL
    case name

    var id: String { rawValue }

    /// Short label for the sort control.
    var label: String {
        switch self {
        case .totalPL: return "Total P/L"
        case .todayPL: return "Today's P/L"
        case .name: return "Name"
        }
    }

    /// The natural direction when this key is first selected: A→Z for names,
    /// largest-first for the P/L keys.
    var defaultAscending: Bool {
        switch self {
        case .name: return true
        case .totalPL, .todayPL: return false
        }
    }
}

/// Which P/L figure a position row displays: gain since entry, or today's move.
enum PLColumn: String, CaseIterable, Identifiable, Sendable {
    case total
    case today

    var id: String { rawValue }

    var label: String {
        switch self {
        case .total: return "Total"
        case .today: return "Today"
        }
    }

    /// The sort key that ranks positions by this column's P/L. Selecting a column
    /// defaults the list to sort by the matching figure, gains → losses.
    var sortKey: PositionSortKey {
        switch self {
        case .total: return .totalPL
        case .today: return .todayPL
        }
    }

    /// The dollar P/L for this column.
    func value(for position: Position) -> Double {
        switch self {
        case .total: return position.unrealizedPL
        case .today: return position.unrealizedIntradayPL
        }
    }

    /// The percentage P/L for this column.
    func percent(for position: Position) -> Double {
        switch self {
        case .total: return position.unrealizedPLPct
        case .today: return position.unrealizedIntradayPLPct
        }
    }
}

extension Array where Element == Position {
    /// Returns the positions ordered by `key` in the given direction. Names sort
    /// alphabetically by the displayed ticker; the P/L keys sort numerically.
    func sorted(by key: PositionSortKey, ascending: Bool) -> [Position] {
        let ordered: [Position]
        switch key {
        case .totalPL:
            ordered = sorted { $0.unrealizedPL < $1.unrealizedPL }
        case .todayPL:
            ordered = sorted { $0.unrealizedIntradayPL < $1.unrealizedIntradayPL }
        case .name:
            ordered = sorted {
                $0.displaySymbol.localizedCaseInsensitiveCompare($1.displaySymbol) == .orderedAscending
            }
        }
        return ascending ? ordered : ordered.reversed()
    }
}
