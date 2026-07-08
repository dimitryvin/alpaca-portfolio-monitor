import ComposableArchitecture
import SwiftUI

/// The Portfolio tab content: header, range picker, equity chart, key stats, and
/// open positions. Pull to refresh; auto-refreshes on a timer while visible.
struct PortfolioView: View {
    @Bindable var store: StoreOf<PortfolioFeature>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if let message = store.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                rangePicker
                EquityChartView(points: store.history?.points ?? [], change: chartChange)
                    .frame(height: 220)

                if let account = store.account {
                    KeyStatsView(account: account)
                }

                PositionsSection(positions: store.positions)
            }
            .padding()
        }
        .refreshable { await store.send(.refreshRequested).finish() }
        .onAppear { store.send(.onAppear) }
        .overlay(alignment: .top) {
            if store.isLoading && store.account == nil {
                ProgressView().padding(.top, 40)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let account = store.account {
                Text(CurrencyFormatter.full.string(from: account.equity))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .contentTransition(.numericText())
                HStack(spacing: 6) {
                    Image(systemName: account.todaysChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text(CurrencyFormatter.full.signedString(from: account.todaysChange))
                    Text("(\(PercentFormatter.signed(account.todaysChangePct)))")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.forChange(account.todaysChange))
            } else {
                Text("—")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(.secondary)
            }

            if let updated = store.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var rangePicker: some View {
        Picker("Range", selection: $store.selectedRange.sending(\.rangeChanged)) {
            ForEach(ChartRange.allCases) { range in
                Text(range.label).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    /// Signed change used to tint the chart: today's change for 1D, else the
    /// overall series change.
    private var chartChange: Double {
        if store.selectedRange == .day, let account = store.account {
            return account.todaysChange
        }
        return store.history?.overallChange ?? 0
    }
}

#Preview {
    NavigationStack {
        PortfolioView(
            store: Store(
                initialState: PortfolioFeature.State(
                    credentials: Credentials(keyID: "k", secret: "s")
                )
            ) {
                PortfolioFeature()
            } withDependencies: {
                $0.alpacaAPI = .preview
            }
        )
        .navigationTitle("Portfolio")
    }
}
