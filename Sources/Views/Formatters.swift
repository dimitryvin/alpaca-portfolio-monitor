import Foundation

/// Shared number/currency formatting helpers used across views.
enum CurrencyFormatter {
    /// Full currency, e.g. "$12,345.67".
    static let full: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        return f
    }()

    /// Compact currency for the menu bar, e.g. "$12,346" (no cents).
    static let compact: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f
    }()
}

extension NumberFormatter {
    /// Non-optional convenience: returns a formatted string or a sensible fallback.
    func string(from value: Double) -> String {
        string(from: NSNumber(value: value)) ?? "$0"
    }

    /// Signed currency, prefixing "+" for positive values (e.g. "+$148.00").
    func signedString(from value: Double) -> String {
        let formatted = string(from: abs(value))
        if value > 0 { return "+\(formatted)" }
        if value < 0 { return "-\(formatted)" }
        return formatted
    }
}

enum PercentFormatter {
    /// Signed percent, e.g. "+1.23%".
    static func signed(_ value: Double) -> String {
        let sign = value > 0 ? "+" : (value < 0 ? "-" : "")
        return "\(sign)\(String(format: "%.2f", abs(value)))%"
    }
}
