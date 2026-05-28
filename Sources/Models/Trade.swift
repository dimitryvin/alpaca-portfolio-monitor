import Foundation

/// A trade row for display: one fill, plus realized P/L for sells.
///
/// `realizedPL`/`realizedPLPct` are populated only for sells that have a known
/// cost basis (i.e. matching prior buys were seen). They are `nil` for buys and
/// for sells whose cost basis couldn't be reconstructed.
struct Trade: Identifiable, Equatable, Sendable {
    let id: String
    let symbol: String
    let isBuy: Bool
    let qty: Double
    let price: Double
    let date: Date
    let realizedPL: Double?
    let realizedPLPct: Double?

    /// Total cash value of the fill (qty × price).
    var value: Double { qty * price }
}
