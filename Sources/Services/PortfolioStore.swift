import Foundation
import Observation

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
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var needsReauth = false
    private(set) var lastUpdated: Date?

    var selectedRange: ChartRange = .day {
        didSet {
            guard oldValue != selectedRange else { return }
            Task { await refresh() }
        }
    }

    /// Whether credentials are present (drives setup vs. content routing).
    var hasCredentials: Bool { credentials?.isValid == true }

    private let refreshInterval: TimeInterval
    private var timerTask: Task<Void, Never>?

    init(refreshInterval: TimeInterval = 60) {
        self.refreshInterval = refreshInterval
        self.credentials = KeychainStore.load()
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
        startAutoRefresh()
        await refresh()
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
        errorMessage = nil
        needsReauth = false
        lastUpdated = nil
    }

    // MARK: - Loading

    /// Starts the app: begins auto-refresh if credentials exist.
    func start() {
        guard hasCredentials else { return }
        startAutoRefresh()
        Task { await refresh() }
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
        } catch AlpacaError.unauthorized {
            self.errorMessage = AlpacaError.unauthorized.errorDescription
            self.needsReauth = true
        } catch {
            self.errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
        isLoading = false
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
            }
        }
    }
}
