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

    /// Market-data host, used for stock price bars.
    static let dataBaseURL = URL(string: "https://data.alpaca.markets")!

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

    /// Fetches reference data for a single asset (company name, exchange, class).
    func fetchAsset(symbol: String) async throws -> Asset {
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? symbol
        return try await get(path: "/v2/assets/\(encoded)", query: [], as: Asset.self)
    }

    /// Fetches historical price bars for a stock over the given range, from the
    /// Market Data host. Uses the free IEX feed so it works on any account
    /// (SIP requires a paid market-data subscription).
    func fetchBars(symbol: String, range: ChartRange, now: Date = Date()) async throws -> [StockBar] {
        let start = ISO8601DateFormatter.string(
            from: range.barStart(from: now),
            timeZone: TimeZone(identifier: "UTC")!,
            formatOptions: [.withInternetDateTime]
        )
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? symbol
        let response = try await get(
            path: "/v2/stocks/\(encoded)/bars",
            query: [
                URLQueryItem(name: "timeframe", value: range.barTimeframe),
                URLQueryItem(name: "start", value: start),
                URLQueryItem(name: "limit", value: "10000"),
                URLQueryItem(name: "adjustment", value: "split"),
                URLQueryItem(name: "feed", value: "iex"),
                URLQueryItem(name: "sort", value: "asc"),
            ],
            baseURL: Self.dataBaseURL,
            as: StockBarsResponse.self
        )
        return response.bars ?? []
    }

    /// Fetches all fill activities (executed trades), paging through results.
    func fetchActivities() async throws -> [Activity] {
        let pageSize = 100
        var all: [Activity] = []
        var pageToken: String?

        repeat {
            var query = [
                URLQueryItem(name: "page_size", value: String(pageSize)),
                URLQueryItem(name: "direction", value: "asc"),
            ]
            if let pageToken {
                query.append(URLQueryItem(name: "page_token", value: pageToken))
            }
            let page = try await get(
                path: "/v2/account/activities/FILL",
                query: query,
                as: [Activity].self
            )
            all.append(contentsOf: page)
            // Alpaca pages by passing the last item's id as the next page_token.
            pageToken = page.count == pageSize ? page.last?.id : nil
            if all.count > 5000 { break } // safety cap
        } while pageToken != nil

        return all
    }

    // MARK: - Request plumbing

    private func get<T: Decodable>(
        path: String,
        query: [URLQueryItem],
        baseURL: URL = AlpacaClient.baseURL,
        as type: T.Type
    ) async throws -> T {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
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
