import SwiftUI

@main
struct AlpacaMonitorApp: App {
    @State private var store = PortfolioStore()

    var body: some Scene {
        MenuBarExtra {
            RootView()
                .environment(store)
                .frame(width: 360)
        } label: {
            MenuBarLabel(account: store.account, needsReauth: store.needsReauth)
        }
        .menuBarExtraStyle(.window)
    }
}
