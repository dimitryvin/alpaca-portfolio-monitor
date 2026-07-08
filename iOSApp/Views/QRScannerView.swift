import AVFoundation
import SwiftUI
import UIKit

/// A live camera viewfinder that reports the string value of the first QR code it
/// sees. On the Simulator (no camera) it simply shows a black view — use the
/// manual-entry fallback there.
struct QRScannerView: UIViewControllerRepresentable {
    /// Called on the main actor with the decoded QR string. Fires once per code.
    var onFound: @MainActor (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onFound = onFound
        return controller
    }

    func updateUIViewController(_ controller: QRScannerViewController, context: Context) {
        controller.onFound = onFound
    }
}

/// Wraps a non-`Sendable` value so it can be handed to a background queue under
/// strict concurrency. The session is only ever touched on `sessionQueue`.
private struct UncheckedBox<Value>: @unchecked Sendable {
    let value: Value
}

@MainActor
final class QRScannerViewController: UIViewController {
    var onFound: (@MainActor (String) -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.alpacamonitor.mobile.qr-session")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let delegate = MetadataDelegate()
    private var hasReported = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        delegate.onFound = { [weak self] code in
            guard let self, !self.hasReported else { return }
            self.hasReported = true
            self.onFound?(code)
        }
        AVCaptureDevice.requestAccess(for: .video) { granted in
            guard granted else { return }
            Task { @MainActor [weak self] in self?.configure() }
        }
    }

    private func configure() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(delegate, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.layer.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer

        setRunning(true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        setRunning(false)
    }

    private func setRunning(_ running: Bool) {
        let box = UncheckedBox(value: session)
        sessionQueue.async {
            if running, !box.value.isRunning {
                box.value.startRunning()
            } else if !running, box.value.isRunning {
                box.value.stopRunning()
            }
        }
    }
}

/// The capture callback runs on the main queue (we pass `.main` above), so it can
/// safely hop back to the main actor to deliver the result.
private final class MetadataDelegate: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    var onFound: (@MainActor (String) -> Void)?

    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let value = object.stringValue else { return }
        // The delegate queue is `.main`, so we're already on the main thread; hop to
        // the main actor without capturing `self` (only the Sendable handler + value).
        let handler = onFound
        MainActor.assumeIsolated {
            handler?(value)
        }
    }
}
