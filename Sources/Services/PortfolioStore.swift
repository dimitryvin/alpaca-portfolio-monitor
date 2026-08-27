import Foundation
import Observation
import OSLog

/// Central observable state for the app: holds credentials, fetched data, the
/// selected chart range, and drives periodic refreshes.
@MainActor
@Observable
final class PortfolioStore {
    // MARK: - Published state

    private(set) var credentials: Credentials?
    private(set) var account: Account?
    private(set) var history: PortfolioHistory?
    private(set) var positions: [Position] = []
    /// Company reference data by lookup symbol (underlying for options), cached
    /// across refreshes so names aren't re-fetched every cycle.
    private(set) var assets: [String: Asset] = [:]
    private(set) var isLoading = false
    /// True only while a range change is fetching, so the chart shows a loader
    /// without flashing on the silent 60-second refresh.
    private(set) var isChartLoading = false
    private(set) var errorMessage: String?
    private(set) var needsReauth = false
    private(set) var lastUpdated: Date?

    // Trades tab state (loaded lazily when the tab is first shown).
    private(set) var trades: [Trade] = []
    private(set) var tradesLoaded = false
    private(set) var isLoadingTrades = false
    private(set) var tradesError: String?

    // New-trade detection for notifications. The first successful trades fetch
    // only records a baseline so historical fills don't flood Notification
    // Center at launch; later fetches notify on any fill ID not seen before.
    private var knownTradeIDs: Set<String> = []
    private var hasTradeBaseline = false

    /// Total realized P/L across all sells that had a known cost basis.
    var totalRealizedPL: Double {
        trades.compactMap(\.realizedPL).reduce(0, +)
    }

    var selectedRange: ChartRange = .day {
        didSet {
            guard oldValue != selectedRange else { return }
            isChartLoading = true
            Task { await refresh() }
        }
    }

    /// Whether credentials are present (drives setup vs. content routing).
    var hasCredentials: Bool { credentials?.isValid == true }

    private let refreshInterval: TimeInterval
    private var timerTask: Task<Void, Never>?

    private static let log = Logger(
        subsystem: "com.alpacamonitor.AlpacaPortfolioMonitor",
        category: "refresh"
    )

    init(refreshInterval: TimeInterval = 60) {
        self.refreshInterval = refreshInterval
        self.credentials = KeychainStore.load()
        // Begin fetching immediately at launch so the menu bar shows the value
        // and change without the user having to open the popover first.
        start()
    }

    // MARK: - Credential lifecycle

    /// Validates the given credentials against `GET /v2/account`, and on success
    /// persists them and starts loading data. Throws `AlpacaError` on failure.
    func signIn(with credentials: Credentials) async throws {
        let client = AlpacaClient(credentials: credentials)
        _ = try await client.fetchAccount() // validation round-trip
        try KeychainStore.save(credentials)
        self.credentials = credentials
        self.needsReauth = false
        await TradeNotifier.shared.requestAuthorization()
        startAutoRefresh()
        await refresh()
        await pollTrades() // records the trade baseline for this account
    }

    /// Clears stored credentials and resets state back to setup.
    func signOut() {
        KeychainStore.clear()
        timerTask?.cancel()
        timerTask = nil
        credentials = nil
        account = nil
        history = nil
        positions = []
        assets = [:]
        isChartLoading = false
        trades = []
        tradesLoaded = false
        tradesError = nil
        knownTradeIDs = []
        hasTradeBaseline = false
        errorMessage = nil
        needsReauth = false
        lastUpdated = nil
    }

    // MARK: - Trades

    /// Loads fill activities and builds the trades list with realized P/L.
    /// No-op if already loaded unless `force` is set. Surfaces errors in the UI.
    func loadTrades(force: Bool = false) async {
        guard let credentials else { return }
        if tradesLoaded && !force { return }
        isLoadingTrades = true
        tradesError = nil
        do {
            applyTrades(try await fetchTrades(using: credentials))
            self.tradesLoaded = true
            Self.log.info("trades loaded: \(self.trades.count, privacy: .public)")
        } catch AlpacaError.unauthorized {
            self.tradesError = AlpacaError.unauthorized.errorDescription
            self.needsReauth = true
        } catch {
            self.tradesError = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            Self.log.error("trades load failed: \(error.localizedDescription, privacy: .public)")
        }
        isLoadingTrades = false
    }

    /// Background trades poll driven by the auto-refresh timer: refreshes the
    /// list and posts notifications for newly executed fills. Errors are logged
    /// only, since this runs without user interaction.
    private func pollTrades() async {
        guard let credentials else { return }
        do {
            applyTrades(try await fetchTrades(using: credentials))
            self.tradesLoaded = true
        } catch {
            Self.log.error("trades poll failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Fetches fill activities and builds the display trades (most-recent-first).
    private func fetchTrades(using credentials: Credentials) async throws -> [Trade] {
        let client = AlpacaClient(credentials: credentials)
        let activities = try await client.fetchActivities()
        return TradeBuilder.build(from: activities)
    }

    /// Replaces the trades list and, once a baseline has been recorded, posts a
    /// notification for each newly seen fill. The first call only records the
    /// baseline so historical trades don't trigger a flood of notifications.
    private func applyTrades(_ newTrades: [Trade]) {
        if hasTradeBaseline {
            // `newTrades` is most-recent-first; notify oldest-first so the
            // newest fill ends up at the top of Notification Center.
            let fresh = newTrades.filter { !knownTradeIDs.contains($0.id) }.reversed()
            for trade in fresh {
                TradeNotifier.shared.notify(of: trade)
            }
            if !fresh.isEmpty {
                Self.log.info("posted \(fresh.count, privacy: .public) trade notification(s)")
            }
        }
        knownTradeIDs = Set(newTrades.map(\.id))
        hasTradeBaseline = true
        trades = newTrades
    }

    // MARK: - Loading

    /// Starts the app: begins auto-refresh if credentials exist.
    func start() {
        guard hasCredentials else { return }
        Task { await TradeNotifier.shared.requestAuthorization() }
        startAutoRefresh()
        Task { await refresh() }
        // Establish the trade baseline once at launch (not on every popover
        // open) so subsequent polls can detect genuinely new fills.
        if !hasTradeBaseline {
            Task { await pollTrades() }
        }
    }

    /// Fetches account, history, and positions concurrently for the current range.
    func refresh() async {
        guard let credentials else { return }
        isLoading = true
        errorMessage = nil
        let client = AlpacaClient(credentials: credentials)
        let range = selectedRange

        do {
            async let account = client.fetchAccount()
            async let history = client.fetchPortfolioHistory(range: range)
            async let positions = client.fetchPositions()

            self.account = try await account
            self.history = try await history
            self.positions = try await positions
            self.lastUpdated = Date()
            self.needsReauth = false
            Self.log.info("refresh ok: positions=\(self.positions.count, privacy: .public), historyPoints=\(self.history?.points.count ?? 0, privacy: .public)")
            // Resolve company names for any holdings we don't have yet.
            let missing = Set(self.positions.map(\.displaySymbol)).subtracting(self.assets.keys)
            if !missing.isEmpty {
                Task { await self.loadAssetNames(for: missing) }
            }
        } catch AlpacaError.unauthorized {
            self.errorMessage = AlpacaError.unauthorized.errorDescription
            self.needsReauth = true
            Self.log.error("refresh unauthorized")
        } catch {
            self.errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            Self.log.error("refresh failed: \(error.localizedDescription, privacy: .public)")
        }
        isLoading = false
        isChartLoading = false
    }

    /// Fetches and caches company reference data for the given lookup symbols,
    /// concurrently. Failures are ignored: a missing name just falls back to the
    /// ticker in the UI.
    private func loadAssetNames(for symbols: Set<String>) async {
        guard let credentials, !symbols.isEmpty else { return }
        let client = AlpacaClient(credentials: credentials)
        await withTaskGroup(of: (String, Asset)?.self) { group in
            for symbol in symbols {
                group.addTask {
                    guard let asset = try? await client.fetchAsset(symbol: symbol) else { return nil }
                    return (symbol, asset)
                }
            }
            for await pair in group {
                if let pair { self.assets[pair.0] = pair.1 }
            }
        }
    }

    // MARK: - Auto refresh

    private func startAutoRefresh() {
        timerTask?.cancel()
        let interval = refreshInterval
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                await self?.refresh()
                await self?.pollTrades()
            }
        }
    }
}
