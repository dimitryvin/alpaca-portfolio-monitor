import ComposableArchitecture
import SwiftUI

/// The paired dashboard: a tab bar over Portfolio and Trades, each with a gear
/// menu to disconnect the phone.
struct DashboardView: View {
    @Bindable var store: StoreOf<DashboardFeature>

    var body: some View {
        TabView(selection: $store.selectedTab) {
            NavigationStack {
                PortfolioView(store: store.scope(state: \.portfolio, action: \.portfolio))
                    .navigationTitle("Portfolio")
                    .toolbar { settingsMenu }
            }
            .tabItem { Label("Portfolio", systemImage: "chart.line.uptrend.xyaxis") }
            .tag(DashboardFeature.State.Tab.portfolio)

            NavigationStack {
                TradesView(store: store.scope(state: \.trades, action: \.trades))
                    .navigationTitle("Trades")
                    .toolbar { settingsMenu }
            }
            .tabItem { Label("Trades", systemImage: "list.bullet.rectangle") }
            .tag(DashboardFeature.State.Tab.trades)
        }
    }

    @ToolbarContentBuilder
    private var settingsMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button(role: .destructive) {
                    store.send(.disconnectTapped)
                } label: {
                    Label("Disconnect", systemImage: "iphone.slash")
                }
            } label: {
                Image(systemName: "gearshape")
            }
        }
    }
}
