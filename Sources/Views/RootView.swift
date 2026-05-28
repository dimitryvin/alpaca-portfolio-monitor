import SwiftUI

/// Routes between the setup screen and the portfolio popover based on whether
/// valid credentials are present (or re-auth is required).
struct RootView: View {
    @Environment(PortfolioStore.self) private var store

    var body: some View {
        Group {
            if store.hasCredentials && !store.needsReauth {
                PopoverView()
            } else {
                SetupView()
            }
        }
        .task { store.start() }
    }
}
