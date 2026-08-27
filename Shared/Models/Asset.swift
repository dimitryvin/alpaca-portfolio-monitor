import Foundation

/// A tradable asset. Maps an element of `GET /v2/assets/{symbol_or_id}`.
///
/// Used to resolve a ticker's human company name and surface reference details
/// (exchange, class, trading flags) on the stock detail screen.
struct Asset: Codable, Equatable, Sendable, Identifiable {
    let symbol: String
    /// Human-readable company / instrument name, e.g. "Apple Inc. Common Stock".
    let name: String
    let exchange: String?
    let assetClass: String?
    let tradable: Bool?
    let fractionable: Bool?
    let shortable: Bool?
    let marginable: Bool?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case symbol
        case name
        case exchange
        case assetClass = "class"
        case tradable
        case fractionable
        case shortable
        case marginable
        case status
    }

    var id: String { symbol }

    init(
        symbol: String,
        name: String,
        exchange: String? = nil,
        assetClass: String? = nil,
        tradable: Bool? = nil,
        fractionable: Bool? = nil,
        shortable: Bool? = nil,
        marginable: Bool? = nil,
        status: String? = nil
    ) {
        self.symbol = symbol
        self.name = name
        self.exchange = exchange
        self.assetClass = assetClass
        self.tradable = tradable
        self.fractionable = fractionable
        self.shortable = shortable
        self.marginable = marginable
        self.status = status
    }
}
