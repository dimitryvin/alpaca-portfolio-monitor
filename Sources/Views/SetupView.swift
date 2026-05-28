import SwiftUI

/// First-run / re-auth screen: collects the Alpaca Key ID + Secret, validates
/// them against the live API, and stores them in the Keychain on success.
struct SetupView: View {
    @Environment(PortfolioStore.self) private var store

    @State private var keyID = ""
    @State private var secret = ""
    @State private var isValidating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Connect to Alpaca")
                    .font(.headline)
                Text("Enter your **live** API key and secret. Read-only access — this app never places trades.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("API Key ID").font(.caption).foregroundStyle(.secondary)
                TextField("PK… / AK…", text: $keyID)
                    .textFieldStyle(.roundedBorder)
                    .disableAutocorrection(true)

                Text("API Secret Key").font(.caption).foregroundStyle(.secondary)
                SecureField("Secret", text: $secret)
                    .textFieldStyle(.roundedBorder)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Link("Get API keys", destination: URL(string: "https://app.alpaca.markets/account/profile")!)
                    .font(.caption)
                Spacer()
                Button {
                    Task { await validate() }
                } label: {
                    if isValidating {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Connect")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit)
            }

            Divider()
            HStack {
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
        }
        .padding(16)
        .onAppear {
            // Pre-fill the key ID on re-auth so the user only re-enters the secret.
            if let existing = store.credentials { keyID = existing.keyID }
        }
    }

    private var canSubmit: Bool {
        !keyID.trimmingCharacters(in: .whitespaces).isEmpty
            && !secret.isEmpty
            && !isValidating
    }

    private func validate() async {
        isValidating = true
        errorMessage = nil
        let credentials = Credentials(
            keyID: keyID.trimmingCharacters(in: .whitespaces),
            secret: secret.trimmingCharacters(in: .whitespaces)
        )
        do {
            try await store.signIn(with: credentials)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
        isValidating = false
    }
}
