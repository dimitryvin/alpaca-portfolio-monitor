import Foundation

/// Errors surfaced by `AlpacaClient`.
enum AlpacaError: Error, Equatable, LocalizedError {
    case unauthorized
    case http(Int)
    case network(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Invalid API key or secret."
        case .http(let code):
            return "Alpaca returned HTTP \(code)."
        case .network(let message):
            return "Network error: \(message)"
        case .decoding(let message):
            return "Could not read response: \(message)"
        }
    }
}

/// Read-only client for the Alpaca live trading API.
///
/// Only `GET` requests are issued; no order/trade endpoints are reachable here.
struct AlpacaClient: Sendable {
    /// Live trading API host. (The app is live-only by design.)
    static let baseURL = URL(string: "https://api.alpaca.markets")!

    let credentials: Credentials
    private let session: URLSession

    init(credentials: Credentials, session: URLSession = .shared) {
        self.credentials = credentials
        self.session = session
    }

    // MARK: - Endpoints

    func fetchAccount() async throws -> Account {
        try await get(path: "/v2/account", query: [], as: Account.self)
    }

    func fetchPortfolioHistory(range: ChartRange) async throws -> PortfolioHistory {
        try await get(
            path: "/v2/account/portfolio/history",
            query: [
                URLQueryItem(name: "period", value: range.period),
                URLQueryItem(name: "timeframe", value: range.timeframe),
            ],
            as: PortfolioHistory.self
        )
    }

    func fetchPositions() async throws -> [Position] {
        try await get(path: "/v2/positions", query: [], as: [Position].self)
    }

    // MARK: - Request plumbing

    private func get<T: Decodable>(
        path: String,
        query: [URLQueryItem],
        as type: T.Type
    ) async throws -> T {
        var components = URLComponents(
            url: Self.baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        if !query.isEmpty { components.queryItems = query }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue(credentials.keyID, forHTTPHeaderField: "APCA-API-KEY-ID")
        request.setValue(credentials.secret, forHTTPHeaderField: "APCA-API-SECRET-KEY")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AlpacaError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AlpacaError.network("No HTTP response")
        }
        switch http.statusCode {
        case 200...299:
            break
        case 401, 403:
            throw AlpacaError.unauthorized
        default:
            throw AlpacaError.http(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AlpacaError.decoding(error.localizedDescription)
        }
    }
}
