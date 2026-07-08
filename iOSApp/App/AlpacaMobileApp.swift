import ComposableArchitecture
import SwiftUI

@main
struct AlpacaMobileApp: App {
    @MainActor
    static let store = makeStore()

    var body: some Scene {
        WindowGroup {
            AppView(store: Self.store)
        }
    }

    @MainActor
    private static func makeStore() -> StoreOf<AppFeature> {
        #if DEBUG
        // Demo mode for previews/screenshots: launch straight into a populated
        // dashboard backed by canned data. Never compiled into release builds and
        // only active when explicitly requested via the environment.
        if ProcessInfo.processInfo.environment["ALPACA_DEMO"] == "1" {
            return Store(
                initialState: AppFeature.State(
                    dashboard: DashboardFeature.State(
                        credentials: Credentials(keyID: "demo", secret: "demo")
                    )
                )
            ) {
                AppFeature()
            } withDependencies: {
                $0.alpacaAPI = .preview
            }
        }
        #endif
        return Store(initialState: AppFeature.initialState()) {
            AppFeature()
        }
    }
}
