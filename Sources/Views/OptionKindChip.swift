import SwiftUI

/// A small tinted capsule marking an option contract as a call (green) or put
/// (red), for quick bullish/bearish scanning. Sits next to the underlying
/// ticker, visually distinct from the blue/orange BUY/SELL badge.
struct OptionKindChip: View {
    let kind: OptionSymbol.Kind

    private var color: Color { kind == .call ? .green : .red }
    private var text: String { kind == .call ? "CALL" : "PUT" }

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundStyle(color)
    }
}
