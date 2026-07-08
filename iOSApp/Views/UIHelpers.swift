import SwiftUI

extension Color {
    /// Green for gains, red for losses, secondary for flat.
    static func forChange(_ value: Double) -> Color {
        value > 0 ? .green : (value < 0 ? .red : .secondary)
    }
}

/// Display helpers for an instrument symbol that may be an OCC option code.
enum SymbolDisplay {
    /// The primary label: the underlying ticker for options, else the raw symbol.
    static func title(_ symbol: String) -> String {
        OptionSymbol(symbol)?.underlying ?? symbol
    }

    /// A human subtitle for options (e.g. "Jul 10 · $14 Call"), or `nil` for equities.
    static func optionSubtitle(_ symbol: String) -> String? {
        guard let option = OptionSymbol(symbol) else { return nil }
        return "\(option.expirationText) · \(option.strikeText) \(option.kindLabel)"
    }
}
