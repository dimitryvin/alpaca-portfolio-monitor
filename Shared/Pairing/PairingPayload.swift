import Foundation

/// The data encoded into the pairing QR code that the macOS app displays and the
/// iOS companion app scans to receive Alpaca credentials.
///
/// Serialized as compact JSON with short keys to keep the QR low-density and easy
/// to scan. The payload is versioned so future changes can be detected and rejected
/// cleanly rather than silently mis-decoded.
///
/// - Note: The credentials travel in plaintext inside the QR. This is intentional
///   for a personal companion app: the code is shown on-demand on the user's own
///   Mac and scanned by the user's own phone, with no server in between. Alpaca
///   keys can be regenerated if ever exposed.
struct PairingPayload: Codable, Equatable, Sendable {
    /// Schema version. Bump when the shape changes incompatibly.
    static let currentVersion = 1
    /// The only environment the app talks to (Alpaca live trading API).
    static let liveEnvironment = "live"

    let version: Int
    let keyID: String
    let secret: String
    let environment: String

    enum CodingKeys: String, CodingKey {
        case version = "v"
        case keyID = "k"
        case secret = "s"
        case environment = "e"
    }

    init(credentials: Credentials, environment: String = PairingPayload.liveEnvironment) {
        self.version = Self.currentVersion
        self.keyID = credentials.keyID
        self.secret = credentials.secret
        self.environment = environment
    }

    /// The credentials carried by this payload.
    var credentials: Credentials {
        Credentials(keyID: keyID, secret: secret)
    }

    // MARK: - Codec

    /// Encodes credentials into the JSON string to render as a QR code.
    static func encode(_ credentials: Credentials) -> String {
        let payload = PairingPayload(credentials: credentials)
        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8) else { return "" }
        return json
    }

    /// Decodes a scanned QR string into a payload, or `nil` if it isn't a valid,
    /// current-version pairing code with non-empty credentials.
    static func decode(_ raw: String) -> PairingPayload? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let payload = try? JSONDecoder().decode(PairingPayload.self, from: data),
              payload.version == Self.currentVersion,
              payload.credentials.isValid else { return nil }
        return payload
    }
}
