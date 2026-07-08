import Foundation

/// Alpaca API credentials (a key/secret pair).
///
/// Shared between the macOS menu-bar app and the iOS companion app: the read-only
/// `AlpacaClient` sends these as the `APCA-API-KEY-ID` / `APCA-API-SECRET-KEY`
/// headers, and the pairing QR code carries them from the Mac to the phone.
struct Credentials: Equatable, Sendable {
    let keyID: String
    let secret: String

    var isValid: Bool { !keyID.isEmpty && !secret.isEmpty }
}
