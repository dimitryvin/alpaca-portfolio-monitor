import Foundation

/// Builds display `Trade`s from raw `Activity` fills, computing realized P/L on
/// sells using the **average-cost** method (which matches how Alpaca reports a
/// position's `avg_entry_price`).
///
/// Fills are processed oldest-first to maintain a running cost basis per symbol;
/// the result is returned most-recent-first for display.
enum TradeBuilder {
    private static let epsilon = 1e-9

    static func build(from activities: [Activity]) -> [Trade] {
        let ascending = activities.sorted { ($0.date, $0.id) < ($1.date, $1.id) }

        var heldQty: [String: Double] = [:]
        var heldCost: [String: Double] = [:]
        var trades: [Trade] = []
        trades.reserveCapacity(ascending.count)

        for fill in ascending {
            let symbol = fill.symbol
            let qty = fill.qty
            let price = fill.price

            if fill.isBuy {
                heldQty[symbol, default: 0] += qty
                heldCost[symbol, default: 0] += qty * price
                trades.append(Trade(
                    id: fill.id, symbol: symbol, isBuy: true,
                    qty: qty, price: price, date: fill.date,
                    realizedPL: nil, realizedPLPct: nil
                ))
            } else {
                let held = heldQty[symbol, default: 0]
                if held > epsilon {
                    let avgCost = heldCost[symbol, default: 0] / held
                    let qtySold = min(qty, held)
                    // Cost basis is tracked per share; scale the dollar P/L by the
                    // contract multiplier so options (100 shares/contract) are
                    // correct. The percentage is unaffected (the multiplier cancels).
                    let multiplier = OptionSymbol.contractMultiplier(for: symbol)
                    let realizedPL = (price - avgCost) * qtySold * multiplier
                    let realizedPLPct = avgCost != 0 ? (price - avgCost) / avgCost * 100 : nil
                    heldQty[symbol] = held - qtySold
                    heldCost[symbol] = (heldCost[symbol] ?? 0) - avgCost * qtySold
                    trades.append(Trade(
                        id: fill.id, symbol: symbol, isBuy: false,
                        qty: qty, price: price, date: fill.date,
                        realizedPL: realizedPL, realizedPLPct: realizedPLPct
                    ))
                } else {
                    // No cost basis available (short, or history beyond what we
                    // fetched) — show the sell without a P/L figure.
                    trades.append(Trade(
                        id: fill.id, symbol: symbol, isBuy: false,
                        qty: qty, price: price, date: fill.date,
                        realizedPL: nil, realizedPLPct: nil
                    ))
                }
            }
        }

        return trades.reversed()
    }
}
