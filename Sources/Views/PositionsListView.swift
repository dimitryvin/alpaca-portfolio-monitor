import SwiftUI

/// Scrollable list of open positions sorted by market value (largest first).
struct PositionsListView: View {
    @Environment(PortfolioStore.self) private var store

    private var sorted: [Position] {
        store.positions.sorted { $0.marketValue > $1.marketValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Positions")
                .font(.caption)
                .foregroundStyle(.secondary)

            if sorted.isEmpty {
                Text(store.isLoading ? "Loading…" : "No open positions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(sorted) { position in
                            row(position)
                        }
                    }
                    .padding(.trailing, 2) // breathing room for the scroll indicator
                }
                .frame(height: 168)
            }
        }
    }

    private func row(_ position: Position) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(position.symbol)
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                Text("\(formattedQty(position.qty)) sh")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(CurrencyFormatter.full.string(from: position.marketValue))
                    .font(.callout)
                // Unrealized gain/loss on the position since entry (not today's move).
                HStack(spacing: 4) {
                    Text(PercentFormatter.signed(position.unrealizedPLPct))
                    Text(CurrencyFormatter.full.signedString(from: position.unrealizedPL))
                }
                .font(.caption2)
                .foregroundStyle(changeColor(position.unrealizedPL))
            }
        }
        .padding(.vertical, 2)
    }

    private func formattedQty(_ qty: Double) -> String {
        if qty == qty.rounded() {
            return String(Int(qty))
        }
        return String(format: "%.4f", qty)
    }

    private func changeColor(_ value: Double) -> Color {
        value > 0 ? .green : (value < 0 ? .red : .secondary)
    }
}
