import SwiftUI

/// The open-positions list within the Portfolio tab.
struct PositionsSection: View {
    let positions: [Position]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Positions")
                .font(.headline)

            if positions.isEmpty {
                Text("No open positions")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(positions) { position in
                    PositionRow(position: position)
                    if position.id != positions.last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

private struct PositionRow: View {
    let position: Position

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(SymbolDisplay.title(position.symbol))
                    .font(.body.weight(.medium))
                if let subtitle = SymbolDisplay.optionSubtitle(position.symbol) {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(position.qty.formatted(.number.precision(.fractionLength(0...4)))) shares")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.full.string(from: position.marketValue))
                    .font(.body.weight(.medium))
                HStack(spacing: 4) {
                    Text(CurrencyFormatter.full.signedString(from: position.unrealizedPL))
                    Text("(\(PercentFormatter.signed(position.unrealizedPLPct)))")
                }
                .font(.caption2)
                .foregroundStyle(Color.forChange(position.unrealizedPL))
            }
        }
        .padding(.vertical, 4)
    }
}
