import SwiftUI

/// The open-positions list within the Portfolio tab, with a sort control and a
/// Total/Today P/L toggle in the header. Selecting a P/L column defaults the sort
/// to that column, gains → losses. Rows are tappable and open the stock detail.
struct PositionsSection: View {
    let positions: [Position]
    /// Company reference data by lookup symbol, for the row subtitle.
    var assets: [String: Asset] = [:]
    var onSelect: (Position) -> Void = { _ in }

    @State private var sortKey: PositionSortKey = PLColumn.total.sortKey
    @State private var ascending = PLColumn.total.sortKey.defaultAscending
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
                // Toggling the column defaults the sort to that column's P/L,
                // gains → losses.
                .onChange(of: plColumn) { _, column in
                    sortKey = column.sortKey
                    ascending = false
                }

                ForEach(sorted) { position in
                    Button { onSelect(position) } label: {
                        PositionRow(position: position, column: plColumn, name: name(for: position))
                    }
                    .buttonStyle(.plain)
                    if position.id != sorted.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    /// The company name for an equity row, or `nil` for options (which show the
    /// contract detail) and for names not yet resolved.
    private func name(for position: Position) -> String? {
        guard !position.isOption else { return nil }
        return assets[position.displaySymbol]?.name
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
    /// Resolved company name for equities; `nil` shows the fallback subtitle.
    var name: String?

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(SymbolDisplay.title(position.symbol))
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
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
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
    }

    /// Second line: the contract detail for options, else the company name, else
    /// the share count until the name resolves.
    private var subtitle: String {
        if let optionSubtitle = SymbolDisplay.optionSubtitle(position.symbol) {
            return optionSubtitle
        }
        if let name { return name }
        return "\(position.qty.formatted(.number.precision(.fractionLength(0...4)))) shares"
    }
}
