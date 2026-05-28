import SwiftUI

/// The popover shown when the menu bar item is clicked: chart, key stats,
/// positions, and a footer with refresh state and account controls.
struct PopoverView: View {
    @Environment(PortfolioStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let message = store.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            PortfolioChartView()
            Divider()
            KeyStatsView()
            Divider()
            PositionsListView()
            Divider()
            footer
        }
        .padding(14)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Portfolio")
                    .font(.headline)
                if let account = store.account {
                    Text(CurrencyFormatter.full.string(from: account.equity))
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                    HStack(spacing: 4) {
                        Text(CurrencyFormatter.full.signedString(from: account.todaysChange))
                        Text("(\(PercentFormatter.signed(account.todaysChangePct)))")
                    }
                    .font(.subheadline)
                    .foregroundStyle(changeColor(account.todaysChange))
                }
            }
            Spacer()
            if store.isLoading {
                ProgressView().controlSize(.small)
            }
        }
    }

    private var footer: some View {
        HStack {
            if let updated = store.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh now")

            Menu {
                Button("Change API Keys…") { store.signOut() }
                Divider()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Settings")
        }
    }

    private func changeColor(_ value: Double) -> Color {
        value > 0 ? .green : (value < 0 ? .red : .secondary)
    }
}
