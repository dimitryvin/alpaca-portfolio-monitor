import Foundation

/// Parses Alpaca ISO-8601 timestamps, with or without fractional seconds.
enum AlpacaDate {
    nonisolated(unsafe) private static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    nonisolated(unsafe) private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ string: String) -> Date? {
        withFractional.date(from: string) ?? plain.date(from: string)
    }
}

/// A single execution (fill). Maps an element of
/// `GET /v2/account/activities/FILL`.
struct Activity: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let symbol: String
    let side: String        // "buy" | "sell"
    let qtyRaw: String
    let priceRaw: String
    let transactionTime: String
    let type: String?       // "fill" | "partial_fill"

    enum CodingKeys: String, CodingKey {
        case id, symbol, side, type
        case qtyRaw = "qty"
        case priceRaw = "price"
        case transactionTime = "transaction_time"
    }

    var qty: Double { Double(qtyRaw) ?? 0 }
    var price: Double { Double(priceRaw) ?? 0 }
    var isBuy: Bool { side.lowercased() == "buy" }
    var date: Date { AlpacaDate.parse(transactionTime) ?? .distantPast }
}
