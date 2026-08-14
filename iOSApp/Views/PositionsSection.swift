import SwiftUI

/// The open-positions list within the Portfolio tab, with a sort control and a
/// Total/Today P/L toggle in the header.
struct PositionsSection: View {
    let positions: [Position]

    @State private var sortKey: PositionSortKey = .totalPL
    @State private var ascending = PositionSortKey.totalPL.defaultAscending
    @State private var plColumn: PLColumn = .total

    private var sorted: [Position] {
        positions.sorted(by: sortKey, ascending: ascending)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Positions")
                    .font(.headline)
                Spacer()
                if !positions.isEmpty {
                    sortMenu
                }
            }

            if positions.isEmpty {
                Text("No open positions")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                Picker("P/L", selection: $plColumn) {
                    ForEach(PLColumn.allCases) { column in
                        Text(column.label).tag(column)
                    }
                }
                .pickerStyle(.segmented)

                ForEach(sorted) { position in
                    PositionRow(position: position, column: plColumn)
                    if position.id != sorted.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(PositionSortKey.allCases) { key in
                Button {
                    if sortKey == key {
                        ascending.toggle()
                    } else {
                        sortKey = key
                        ascending = key.defaultAscending
                    }
                } label: {
                    if sortKey == key {
                        Label(key.label, systemImage: ascending ? "chevron.up" : "chevron.down")
                    } else {
                        Text(key.label)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                Text(sortKey.label)
            }
            .font(.subheadline)
        }
    }
}

private struct PositionRow: View {
    let position: Position
    let column: PLColumn

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
                    Text(CurrencyFormatter.full.signedString(from: column.value(for: position)))
                    Text("(\(PercentFormatter.signed(column.percent(for: position))))")
                }
                .font(.caption2)
                .foregroundStyle(Color.forChange(column.value(for: position)))
            }
        }
        .padding(.vertical, 4)
    }
}
