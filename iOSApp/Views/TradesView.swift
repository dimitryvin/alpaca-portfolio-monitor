import ComposableArchitecture
import SwiftUI

/// The Trades tab: total realized P/L header plus a list of fills, newest first.
struct TradesView: View {
    let store: StoreOf<TradesFeature>

    var body: some View {
        Group {
            if store.trades.isEmpty {
                emptyOrLoading
            } else {
                List {
                    Section {
                        HStack {
                            Text("Total realized P/L")
                                .font(.subheadline)
                            Spacer()
                            Text(CurrencyFormatter.full.signedString(from: store.totalRealizedPL))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.forChange(store.totalRealizedPL))
                        }
                    }
                    Section {
                        ForEach(store.trades) { trade in
                            TradeRow(trade: trade)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .refreshable { await store.send(.refreshRequested).finish() }
        .onAppear { store.send(.onAppear) }
    }

    @ViewBuilder
    private var emptyOrLoading: some View {
        if store.isLoading {
            ProgressView()
        } else if let message = store.errorMessage {
            ContentUnavailableView(
                "Couldn't load trades",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
        } else {
            ContentUnavailableView(
                "No trades yet",
                systemImage: "list.bullet.rectangle",
                description: Text("Executed fills will appear here.")
            )
        }
    }
}

private struct TradeRow: View {
    let trade: Trade

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(trade.isBuy ? "BUY" : "SELL")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(trade.isBuy ? Color.green : Color.red)
                    Text(SymbolDisplay.title(trade.symbol))
                        .font(.body.weight(.medium))
                }
                if let subtitle = SymbolDisplay.optionSubtitle(trade.symbol) {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(trade.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.full.string(from: trade.value))
                    .font(.body.weight(.medium))
                Text("\(trade.qty.formatted(.number.precision(.fractionLength(0...4)))) @ \(CurrencyFormatter.full.string(from: trade.price))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let realizedPL = trade.realizedPL {
                    Text(CurrencyFormatter.full.signedString(from: realizedPL))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.forChange(realizedPL))
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        TradesView(
            store: Store(
                initialState: TradesFeature.State(
                    credentials: Credentials(keyID: "k", secret: "s")
                )
            ) {
                TradesFeature()
            } withDependencies: {
                $0.alpacaAPI = .preview
            }
        )
        .navigationTitle("Trades")
    }
}
