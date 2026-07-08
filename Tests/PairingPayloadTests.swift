import Testing
@testable import AlpacaPortfolioMonitor

struct PairingPayloadTests {
    @Test
    func encodeThenDecodeRoundTrips() throws {
        let credentials = Credentials(keyID: "AKTEST123", secret: "s3cr3t/with+symbols=")
        let raw = PairingPayload.encode(credentials)

        let decoded = try #require(PairingPayload.decode(raw))
        #expect(decoded.credentials == credentials)
        #expect(decoded.version == PairingPayload.currentVersion)
        #expect(decoded.environment == PairingPayload.liveEnvironment)
    }

    @Test
    func decodeRejectsNonJSON() {
        #expect(PairingPayload.decode("totally not json") == nil)
        #expect(PairingPayload.decode("") == nil)
    }

    @Test
    func decodeRejectsWrongVersion() {
        let future = #"{"v":999,"k":"AKTEST","s":"secret","e":"live"}"#
        #expect(PairingPayload.decode(future) == nil)
    }

    @Test
    func decodeRejectsEmptyCredentials() {
        let blank = #"{"v":1,"k":"","s":"","e":"live"}"#
        #expect(PairingPayload.decode(blank) == nil)
    }

    @Test
    func decodeToleratesSurroundingWhitespace() throws {
        let credentials = Credentials(keyID: "AKTEST123", secret: "secret")
        let raw = "\n  " + PairingPayload.encode(credentials) + "  \n"
        let decoded = try #require(PairingPayload.decode(raw))
        #expect(decoded.credentials == credentials)
    }
}
