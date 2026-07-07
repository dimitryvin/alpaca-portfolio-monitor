import Foundation

/// A single-leg equity option parsed from its OCC-format symbol.
///
/// Alpaca returns option activity/position symbols in the 21-character OCC
/// scheme with the root left-unpadded, e.g. `TSLL260710C00014000`:
///
/// ```
/// TSLL 260710 C 00014000
/// root  YYMMDD ┃  strike×1000
///              call/put
/// ```
///
/// The trailing 15 characters are fixed-width (`YYMMDD` + `C`/`P` + 8-digit
/// strike), so the root is everything before them. `init?` returns `nil` for
/// plain equity tickers (e.g. `RIVN`) and anything that doesn't match the shape.
struct OptionSymbol: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case call
        case put
    }

    /// The underlying ticker (e.g. `TSLL`).
    let underlying: String
    /// The contract's expiration date (calendar date, no time-of-day meaning).
    let expiration: Date
    let kind: Kind
    /// The strike price in dollars (e.g. `14.0`, `2.5`).
    let strike: Double

    /// The fixed-width contract suffix: `YYMMDD` (6) + `C`/`P` (1) + strike (8).
    private static let suffixLength = 15

    init?(_ raw: String) {
        let symbol = raw.uppercased()
        // Need at least a 1-char root plus the 15-char contract suffix.
        guard symbol.count > Self.suffixLength else { return nil }

        let root = String(symbol.dropLast(Self.suffixLength))
        let suffix = Array(symbol.suffix(Self.suffixLength))

        // Root must start with a letter (rules out digit-only false positives).
        guard let firstRoot = root.first, firstRoot.isLetter,
              root.allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }

        let dateDigits = String(suffix[0..<6])
        let typeChar = suffix[6]
        let strikeDigits = String(suffix[7..<15])

        guard dateDigits.allSatisfy(\.isNumber),
              strikeDigits.allSatisfy(\.isNumber),
              let yy = Int(dateDigits.prefix(2)),
              let month = Int(dateDigits.dropFirst(2).prefix(2)),
              let day = Int(dateDigits.suffix(2)),
              let strikeMills = Int(strikeDigits),
              (1...12).contains(month),
              (1...31).contains(day) else { return nil }

        switch typeChar {
        case "C": self.kind = .call
        case "P": self.kind = .put
        default: return nil
        }

        var components = DateComponents()
        components.year = 2000 + yy
        components.month = month
        components.day = day
        components.hour = 12 // noon UTC, safely inside the calendar day everywhere
        guard let date = Self.utcCalendar.date(from: components) else { return nil }

        self.underlying = root
        self.expiration = date
        self.strike = Double(strikeMills) / 1000
    }

    // MARK: - Contract multiplier

    /// Shares per contract for a standard US equity option. Premiums are quoted
    /// per share, but a contract covers 100 shares, so dollar value and realized
    /// P/L scale by this.
    static let equityContractMultiplier = 100.0

    /// The share multiplier implied by a trade/position `symbol`: 100 for
    /// options, 1 for plain equities. Lets callers price both uniformly as
    /// `qty × price × multiplier` without re-checking the instrument type.
    static func contractMultiplier(for symbol: String) -> Double {
        OptionSymbol(symbol) != nil ? equityContractMultiplier : 1
    }

    // MARK: - Display helpers

    /// `"Call"` / `"Put"`.
    var kindLabel: String { kind == .call ? "Call" : "Put" }

    /// Strike formatted as currency, dropping cents when whole (`"$14"`, `"$2.50"`).
    var strikeText: String {
        strike == strike.rounded()
            ? "$\(Int(strike))"
            : String(format: "$%.2f", strike)
    }

    /// Expiration as an abbreviated month/day, e.g. `"Jul 10"`.
    var expirationText: String { Self.expirationFormatter.string(from: expiration) }

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private static let expirationFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
