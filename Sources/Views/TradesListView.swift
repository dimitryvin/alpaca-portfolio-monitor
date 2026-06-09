import SwiftUI

/// Lists executed trades (fills), newest first. Sells show realized P/L
/// computed from average cost basis.
struct TradesListView: View {
    @Environment(PortfolioStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            summary

            if let error = store.tradesError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if store.trades.isEmpty {
                placeholder
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(store.trades) { trade in
                            row(trade)
                            Divider()
                        }
                    }
                    .padding(.trailing, 2)
                }
                .frame(height: 372)
            }
        }
        // Refresh whenever the Trades tab is selected (the view is recreated on
        // each switch), so the list is current without a manual refresh.
        .task { await store.loadTrades(force: true) }
    }

    // MARK: - Pieces

    private var summary: some View {
        HStack {
            Text("Trades")
                .font(.caption)
                .foregroundStyle(.secondary)
            if store.isLoadingTrades && !store.trades.isEmpty {
                ProgressView().controlSize(.small)
            }
            Spacer()
            if !store.trades.isEmpty {
                Text("Realized P/L: \(CurrencyFormatter.full.signedString(from: store.totalRealizedPL))")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(changeColor(store.totalRealizedPL))
            }
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        Group {
            if store.isLoadingTrades {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Loading trades…")
                }
            } else {
                Text("No trades yet")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 360, alignment: .center)
    }

    private func row(_ trade: Trade) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(trade.symbol)
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                    sideBadge(trade.isBuy)
                }
                Text(trade.date.formatted(.dateTime.month().day().hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(formattedQty(trade.qty)) @ \(CurrencyFormatter.full.string(from: trade.price))")
                    .font(.callout)
                if !trade.isBuy, let pl = trade.realizedPL, let pct = trade.realizedPLPct {
                    HStack(spacing: 4) {
                        Text(PercentFormatter.signed(pct))
                        Text(CurrencyFormatter.full.signedString(from: pl))
                    }
                    .font(.caption2)
                    .foregroundStyle(changeColor(pl))
                } else {
                    Text(CurrencyFormatter.full.string(from: trade.value))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 1)
    }

    private func sideBadge(_ isBuy: Bool) -> some View {
        Text(isBuy ? "BUY" : "SELL")
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                Capsule().fill((isBuy ? Color.blue : Color.orange).opacity(0.18))
            )
            .foregroundStyle(isBuy ? Color.blue : Color.orange)
    }

    private func formattedQty(_ qty: Double) -> String {
        qty == qty.rounded() ? String(Int(qty)) : String(format: "%.4f", qty)
    }

    private func changeColor(_ value: Double) -> Color {
        value > 0 ? .green : (value < 0 ? .red : .secondary)
    }
}
