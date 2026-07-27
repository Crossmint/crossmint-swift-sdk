import Testing

@testable import Wallet

@Suite("SignerLocator")
struct SignerLocatorTests {
    @Test(
        "Produces the expected locator string for each case",
        arguments: [
            (SignerLocator.device(publicKey: "abc123"), "device:abc123"),
            (SignerLocator.email("user@example.com"), "email:user@example.com"),
            (SignerLocator.phone("+15551234567"), "phone:+15551234567"),
            (SignerLocator.externalWallet(address: "0xabc"), "external-wallet:0xabc"),
            (SignerLocator.passkey(credentialId: "cred-1"), "passkey:cred-1"),
            (SignerLocator.apiKey(address: "0xdef"), "api-key:0xdef"),
            (SignerLocator.apiKey(), "api-key"),
            (SignerLocator.server(address: "0x999"), "server:0x999")
        ]
    )
    func producesExpectedValue(locatorAndExpected: (SignerLocator, String)) {
        #expect(locatorAndExpected.0.value == locatorAndExpected.1)
    }

    @Test(
        "Parses known locator strings back into the matching case",
        arguments: [
            ("device:abc123", SignerLocator.device(publicKey: "abc123")),
            ("email:user@example.com", SignerLocator.email("user@example.com")),
            ("phone:+15551234567", SignerLocator.phone("+15551234567")),
            ("external-wallet:0xabc", SignerLocator.externalWallet(address: "0xabc")),
            ("passkey:cred-1", SignerLocator.passkey(credentialId: "cred-1")),
            ("api-key:0xdef", SignerLocator.apiKey(address: "0xdef")),
            ("api-key", SignerLocator.apiKey()),
            ("api-key:api-key", SignerLocator.apiKey()),
            ("server:0x999", SignerLocator.server(address: "0x999"))
        ]
    )
    func parsesKnownLocatorStrings(stringAndExpected: (String, SignerLocator)) throws {
        let parsed = try SignerLocator(from: stringAndExpected.0)
        #expect(parsed == stringAndExpected.1)
    }

    @Test("Throws signerLocatorError for an unknown prefix")
    func throwsForUnknownPrefix() {
        #expect(throws: WalletError.self) {
            try SignerLocator(from: "carrier-pigeon:0xabc")
        }
    }

    @Test("Throws signerLocatorError when a known prefix has no value")
    func throwsForMissingValue() {
        #expect(throws: WalletError.self) {
            try SignerLocator(from: "email")
        }
    }

    @Test("Round-trips through value and back")
    func roundTripsThroughValue() throws {
        let original = SignerLocator.email("round-trip@example.com")
        let parsed = try SignerLocator(from: original.value)
        #expect(parsed == original)
    }
}
