import SwiftUI

/// Compact grid of key account stats: equity, today's P/L, cash, buying power.
struct KeyStatsView: View {
    @Environment(PortfolioStore.self) private var store

    private let columns = [
        GridItem(.flexible(), alignment: .leading),
        GridItem(.flexible(), alignment: .leading),
    ]

    var body: some View {
        if let account = store.account {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                stat("Equity", CurrencyFormatter.full.string(from: account.equity))
                stat(
                    "Today's P/L",
                    CurrencyFormatter.full.signedString(from: account.todaysChange),
                    color: changeColor(account.todaysChange),
                    detail: PercentFormatter.signed(account.todaysChangePct)
                )
                stat("Cash", CurrencyFormatter.full.string(from: account.cash))
                stat("Buying Power", CurrencyFormatter.full.string(from: account.buyingPower))
            }
        }
    }

    private func stat(
        _ title: String,
        _ value: String,
        color: Color = .primary,
        detail: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Text(value)
                    .font(.system(.callout, design: .rounded).weight(.medium))
                    .foregroundStyle(color)
                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(color)
                }
            }
        }
    }

    private func changeColor(_ value: Double) -> Color {
        value > 0 ? .green : (value < 0 ? .red : .primary)
    }
}
