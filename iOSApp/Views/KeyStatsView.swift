import SwiftUI

/// A 2×2 grid of key account stats.
struct KeyStatsView: View {
    let account: Account

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            StatTile(
                label: "Equity",
                value: CurrencyFormatter.full.string(from: account.equity)
            )
            StatTile(
                label: "Today's P/L",
                value: CurrencyFormatter.full.signedString(from: account.todaysChange),
                detail: PercentFormatter.signed(account.todaysChangePct),
                tint: Color.forChange(account.todaysChange)
            )
            StatTile(
                label: "Cash",
                value: CurrencyFormatter.full.string(from: account.cash)
            )
            StatTile(
                label: "Buying Power",
                value: CurrencyFormatter.full.string(from: account.buyingPower)
            )
        }
    }
}

private struct StatTile: View {
    let label: String
    let value: String
    var detail: String?
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(tint)
            // Always reserve the detail line so every tile is the same height as
            // the ones that show a percentage (e.g. Today's P/L).
            Text(detail ?? " ")
                .font(.caption2)
                .foregroundStyle(tint)
                .opacity(detail == nil ? 0 : 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 14))
    }
}
