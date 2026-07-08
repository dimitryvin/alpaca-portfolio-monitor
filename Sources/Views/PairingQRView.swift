import AppKit
import CoreImage.CIFilterBuiltins
import SwiftUI

/// A sheet that renders the current credentials as a QR code for the iOS companion
/// app to scan. Shown from the popover's gear menu ("Connect iPhone…").
struct PairingQRView: View {
    let credentials: Credentials
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Connect iPhone")
                .font(.headline)

            if let image = qrImage {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 232, height: 232)
                    .padding(8)
                    .background(.white, in: .rect(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary)
                    .frame(width: 232, height: 232)
                    .overlay {
                        Text("Couldn't generate code")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
            }

            Text("Open **Alpaca Monitor** on your iPhone and scan this code to connect.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(width: 260)

            Label("This code contains your API keys — keep it private.", systemImage: "lock.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(width: 320)
    }

    private var qrImage: NSImage? {
        QRCodeRenderer.image(for: PairingPayload.encode(credentials))
    }
}

/// Renders a string into a crisp QR code `NSImage` via Core Image.
enum QRCodeRenderer {
    static func image(for string: String, scale: CGFloat = 12) -> NSImage? {
        guard !string.isEmpty else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: scaled.extent.width, height: scaled.extent.height))
    }
}
