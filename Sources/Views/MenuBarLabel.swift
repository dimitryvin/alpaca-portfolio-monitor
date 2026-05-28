import SwiftUI

/// The always-visible menu bar text: portfolio value + today's change %.
/// Falls back to a neutral glyph before the first load or when re-auth is needed.
struct MenuBarLabel: View {
    let account: Account?
    let needsReauth: Bool

    var body: some View {
        if needsReauth {
            Image(systemName: "exclamationmark.triangle")
        } else if let account {
            Text(labelText(for: account))
        } else {
            Image(systemName: "chart.line.uptrend.xyaxis")
        }
    }

    private func labelText(for account: Account) -> String {
        let value = CurrencyFormatter.compact.string(from: account.equity)
        let pct = account.todaysChangePct
        let arrow = pct > 0 ? "▲" : (pct < 0 ? "▼" : "▪")
        let pctText = String(format: "%.2f%%", abs(pct))
        return "\(value)  \(arrow)\(pctText)"
    }
}
