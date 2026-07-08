import ComposableArchitecture
import SwiftUI

/// The pairing screen: a live camera viewfinder that scans the QR code shown by
/// the macOS app, with a manual key-entry fallback for devices without a camera.
struct PairingView: View {
    @Bindable var store: StoreOf<PairingFeature>

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            QRScannerView { code in
                store.send(.scanned(code))
            }
            .ignoresSafeArea()

            scrim

            VStack(spacing: 20) {
                Spacer()
                reticle
                Text("Scan the pairing code")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Open Alpaca Monitor on your Mac, choose the gear menu → **Connect iPhone…**, and point your camera at the code.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 32)

                if let message = store.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.yellow)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                Button {
                    store.showManualEntry = true
                } label: {
                    Text("Enter keys manually")
                        .font(.callout.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.15), in: .capsule)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }

            if store.isValidating {
                Color.black.opacity(0.4).ignoresSafeArea()
                ProgressView("Connecting…")
                    .tint(.white)
                    .foregroundStyle(.white)
                    .padding(24)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
            }
        }
        .sheet(isPresented: $store.showManualEntry) {
            ManualEntryView(store: store)
        }
    }

    private var scrim: some View {
        LinearGradient(
            colors: [.black.opacity(0.65), .black.opacity(0.2), .black.opacity(0.65)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var reticle: some View {
        RoundedRectangle(cornerRadius: 24)
            .stroke(.white.opacity(0.9), lineWidth: 3)
            .frame(width: 220, height: 220)
            .shadow(radius: 8)
    }
}

/// Manual key/secret entry — the fallback when the camera can't be used.
private struct ManualEntryView: View {
    @Bindable var store: StoreOf<PairingFeature>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("API Key ID", text: $store.manualKeyID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("API Secret", text: $store.manualSecret)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Alpaca live API credentials")
                } footer: {
                    Text("These are the same read-only keys the Mac app uses. Find them at app.alpaca.markets → your profile.")
                }

                if let message = store.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                Section {
                    Button {
                        store.send(.connectManuallyTapped)
                    } label: {
                        if store.isValidating {
                            ProgressView()
                        } else {
                            Text("Connect")
                        }
                    }
                    .disabled(store.isValidating)
                }
            }
            .navigationTitle("Connect Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
