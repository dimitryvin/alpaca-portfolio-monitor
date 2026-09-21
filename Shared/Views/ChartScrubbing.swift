import Charts
import SwiftUI

/// Marks for the scrubbed point: a vertical rule plus a dot on the line.
struct ChartScrubMarks<X: Plottable>: ChartContent {
    let x: PlottableValue<X>
    let y: PlottableValue<Double>
    let tint: Color

    var body: some ChartContent {
        RuleMark(x: x)
            .foregroundStyle(Color.secondary.opacity(0.6))
            .lineStyle(StrokeStyle(lineWidth: 1))
        PointMark(x: x, y: y)
            .foregroundStyle(tint)
            .symbolSize(50)
    }
}

extension View {
    /// Makes a chart scrubbable: hovering (macOS) or long-pressing then dragging
    /// (iOS) reports the cursor as a fraction of the plot width, and `nil` once
    /// the interaction ends. Resolve it with `ChartScrub`, then pass the result
    /// back as `selection`/`label` to show a readout above the marker.
    ///
    /// Reserves a band above the chart for the readout, so the chart is
    /// `ChartScrubMetrics.readoutHeight` shorter than the frame it is given.
    func chartScrubbing(
        selection: ChartSelection?,
        label: String?,
        onScrub: @escaping (Double?) -> Void
    ) -> some View {
        modifier(ChartScrubbingModifier(selection: selection, label: label, onScrub: onScrub))
    }
}

enum ChartScrubMetrics {
    /// Height of the band reserved above the plot for the readout label.
    static let readoutHeight: CGFloat = 16
    /// Gap between the readout label and the top of the plot.
    static let readoutGap: CGFloat = 2
}

private struct ChartScrubbingModifier: ViewModifier {
    let selection: ChartSelection?
    let label: String?
    let onScrub: (Double?) -> Void

    func body(content: Content) -> some View {
        content
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    if let anchor = proxy.plotFrame {
                        let plot = geometry[anchor]
                        ScrubInputLayer { x in
                            onScrub(x.map { fraction(of: $0, in: plot) })
                        }
                        // An overlay, so the label can sit above the plot
                        // without affecting the input layer's layout.
                        .overlay {
                            if let selection, let label {
                                readout(label, at: selection.fraction, in: plot)
                            }
                        }
                    }
                }
            }
            .padding(.top, ChartScrubMetrics.readoutHeight)
    }

    private func fraction(of x: CGFloat, in plot: CGRect) -> Double {
        guard plot.width > 0 else { return 0 }
        return Double((x - plot.minX) / plot.width)
    }

    private func readout(_ label: String, at fraction: Double, in plot: CGRect) -> some View {
        ReadoutLayout(markerX: plot.minX + plot.width * CGFloat(fraction), plot: plot) {
            Text(label)
                .font(.caption2.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
        }
        .allowsHitTesting(false)
    }
}

/// Places the readout label just above the plot, centred over the marker and
/// kept within the plot's horizontal bounds. A `Layout` because the clamp needs
/// the label's measured width in the same pass.
private struct ReadoutLayout: Layout {
    let markerX: CGFloat
    let plot: CGRect

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let label = subviews.first else { return }
        let size = label.sizeThatFits(.unspecified)
        let leading = min(max(markerX - size.width / 2, plot.minX), max(plot.maxX - size.width, plot.minX))
        let top = plot.minY - ChartScrubMetrics.readoutGap - size.height
        label.place(
            at: CGPoint(x: bounds.minX + leading, y: bounds.minY + top),
            anchor: .topLeading,
            proposal: .unspecified
        )
    }
}

// MARK: - Input

#if os(macOS)
/// Reports the pointer's x-position while it hovers over the chart.
private struct ScrubInputLayer: View {
    let onMove: (CGFloat?) -> Void

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location): onMove(location.x)
                case .ended: onMove(nil)
                }
            }
    }
}
#else
/// Reports the touch's x-position from a long press onward.
///
/// A UIKit long-press recognizer rather than a SwiftUI gesture: it knows its
/// location the moment the press is recognized, keeps tracking the drag, and —
/// because it fails as soon as the finger moves early — leaves an enclosing
/// scroll view free to scroll.
private struct ScrubInputLayer: UIViewRepresentable {
    let onMove: (CGFloat?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onMove: onMove) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let press = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handle(_:))
        )
        press.minimumPressDuration = 0.15
        view.addGestureRecognizer(press)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.onMove = onMove
    }

    @MainActor
    final class Coordinator: NSObject {
        var onMove: (CGFloat?) -> Void

        init(onMove: @escaping (CGFloat?) -> Void) {
            self.onMove = onMove
        }

        @objc func handle(_ recognizer: UILongPressGestureRecognizer) {
            switch recognizer.state {
            case .began, .changed:
                onMove(recognizer.location(in: recognizer.view).x)
            default:
                onMove(nil)
            }
        }
    }
}
#endif
