import SwiftUI

/// The popover shown when the menu bar item is clicked: chart, key stats,
/// positions, and a footer with refresh state and account controls.
/// Which section of the popover is visible.
enum PopoverTab: String, CaseIterable, Identifiable {
    case portfolio = "Portfolio"
    case trades = "Trades"
    var id: String { rawValue }
    var label: String { rawValue }
}

struct PopoverView: View {
    @Environment(PortfolioStore.self) private var store
    @State private var tab: PopoverTab = .portfolio
    @State private var showPairingQR = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let message = store.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Picker("View", selection: $tab) {
                ForEach(PopoverTab.allCases) { tab in
                    Text(tab.label).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch tab {
            case .portfolio:
                PortfolioChartView()
                Divider()
                KeyStatsView()
                Divider()
                PositionsListView()
            case .trades:
                TradesListView()
            }

            Divider()
            footer
        }
        .padding(14)
        .sheet(isPresented: $showPairingQR) {
            if let credentials = store.credentials {
                PairingQRView(credentials: credentials)
            }
        }
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
                Task {
                    await store.refresh()
                    if store.tradesLoaded { await store.loadTrades(force: true) }
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh now")

            Menu {
                Toggle("Open at Login", isOn: Binding(
                    get: { LaunchAtLogin.isEnabled },
                    set: { LaunchAtLogin.set($0) }
                ))
                Divider()
                Button("Connect iPhone…") { showPairingQR = true }
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
