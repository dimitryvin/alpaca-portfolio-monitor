import ComposableArchitecture
import SwiftUI

/// Routes between the pairing flow and the paired dashboard based on which of the
/// root feature's child states is present.
struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        if let pairingStore = store.scope(state: \.pairing, action: \.pairing) {
            PairingView(store: pairingStore)
        } else if let dashboardStore = store.scope(state: \.dashboard, action: \.dashboard) {
            DashboardView(store: dashboardStore)
        } else {
            ProgressView()
        }
    }
}

#Preview("Pairing") {
    AppView(
        store: Store(initialState: AppFeature.State(pairing: PairingFeature.State())) {
            AppFeature()
        }
    )
}
