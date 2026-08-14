import SwiftUI

/// Scrollable list of open positions with a sort control and a Total/Today P/L
/// toggle in the header.
struct PositionsListView: View {
    @Environment(PortfolioStore.self) private var store

    @State private var sortKey: PositionSortKey = .totalPL
    @State private var ascending = PositionSortKey.totalPL.defaultAscending
    @State private var plColumn: PLColumn = .total

    private var sorted: [Position] {
        store.positions.sorted(by: sortKey, ascending: ascending)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header

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

    private var header: some View {
        HStack(spacing: 8) {
            Text("Positions")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if !store.positions.isEmpty {
                Picker("P/L", selection: $plColumn) {
                    ForEach(PLColumn.allCases) { column in
                        Text(column.label).tag(column)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .controlSize(.small)
                sortMenu
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
            Image(systemName: "arrow.up.arrow.down")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Sort positions")
    }

    private func row(_ position: Position) -> some View {
        let option = OptionSymbol(position.symbol)
        return HStack {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(option?.underlying ?? position.symbol)
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                    if let option { OptionKindChip(kind: option.kind) }
                }
                Text(subtitle(for: position, option: option))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(CurrencyFormatter.full.string(from: position.marketValue))
                    .font(.callout)
                // Total P/L since entry, or today's move, per the header toggle.
                HStack(spacing: 4) {
                    Text(PercentFormatter.signed(plColumn.percent(for: position)))
                    Text(CurrencyFormatter.full.signedString(from: plColumn.value(for: position)))
                }
                .font(.caption2)
                .foregroundStyle(changeColor(plColumn.value(for: position)))
            }
        }
        .padding(.vertical, 2)
    }

    /// Second line: share count for stocks; contract count + strike + expiration
    /// for options (e.g. "9 contracts · $14 · Exp Jul 10").
    private func subtitle(for position: Position, option: OptionSymbol?) -> String {
        guard let option else { return "\(formattedQty(position.qty)) sh" }
        let unit = position.qty == 1 ? "contract" : "contracts"
        return "\(formattedQty(position.qty)) \(unit) · \(option.strikeText) · Exp \(option.expirationText)"
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
