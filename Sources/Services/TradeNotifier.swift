import Foundation
import UserNotifications
import OSLog

/// Posts local notifications when newly executed trades are detected by the
/// background poll in `PortfolioStore`. Sells include their realized P/L.
@MainActor
final class TradeNotifier {
    static let shared = TradeNotifier()

    private let center = UNUserNotificationCenter.current()

    private static let log = Logger(
        subsystem: "com.alpacamonitor.AlpacaPortfolioMonitor",
        category: "notifications"
    )

    private init() {}

    /// Requests permission to show notifications. Safe to call more than once;
    /// the system only prompts the user the first time.
    func requestAuthorization() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            Self.log.error("notification authorization failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Posts a notification describing a single filled trade. Delivered
    /// immediately; the identifier dedupes repeat posts of the same fill.
    func notify(of trade: Trade) {
        let content = UNMutableNotificationContent()
        content.title = "\(trade.symbol) \(trade.isBuy ? "buy" : "sell") filled"
        content.body = Self.body(for: trade)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "trade-\(trade.id)",
            content: content,
            trigger: nil // deliver now
        )
        center.add(request) { error in
            if let error {
                Self.log.error("failed to post trade notification: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Builds the notification body, e.g.
    /// `"10 @ $150.00 · Realized P/L +$120.00 (+8.70%)"`. Buys omit the P/L part,
    /// as do sells whose cost basis couldn't be reconstructed.
    static func body(for trade: Trade) -> String {
        let qty = trade.qty == trade.qty.rounded()
            ? String(Int(trade.qty))
            : String(format: "%.4f", trade.qty)
        var parts = ["\(qty) @ \(CurrencyFormatter.full.string(from: trade.price))"]

        if !trade.isBuy, let pl = trade.realizedPL {
            let amount = CurrencyFormatter.full.signedString(from: pl)
            if let pct = trade.realizedPLPct {
                parts.append("Realized P/L \(amount) (\(PercentFormatter.signed(pct)))")
            } else {
                parts.append("Realized P/L \(amount)")
            }
        }
        return parts.joined(separator: " · ")
    }
}
