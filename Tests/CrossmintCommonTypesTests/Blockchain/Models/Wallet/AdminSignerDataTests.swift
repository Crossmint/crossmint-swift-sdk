import Testing
import Foundation

@testable import CrossmintCommonTypes

// swiftlint:disable force_unwrapping
struct AdminSignerDataTests {

    // MARK: - ExternalWalletSignerData Tests

    @Test("ExternalWalletSignerData initialization")
    func testExternalWalletSignerDataInit() {
        let address = "0x1234567890123456789012345678901234567890"
        let signer = ExternalWalletSignerData(address: address)

        #expect(signer.address == address)
        #expect(signer.type == .externalWallet)
        #expect(signer.locatorId == address)
    }

    @Test("ExternalWalletSignerData JSON encoding")
    func testExternalWalletSignerDataEncoding() throws {
        let address = "0x1234567890123456789012345678901234567890"
        let signer = ExternalWalletSignerData(address: address)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(signer)
        let json = String(data: data, encoding: .utf8)!

        let expectedJSON = """
        {"address":"\(address)","type":"external-wallet"}
        """

        #expect(json == expectedJSON)
    }

    @Test("ExternalWalletSignerData JSON decoding")
    func testExternalWalletSignerDataDecoding() throws {
        let json = """
        {"type": "external-wallet", "address": "0xABCDEF1234567890"}
        """

        let data = json.data(using: .utf8)!
        let signer = try JSONDecoder().decode(ExternalWalletSignerData.self, from: data)

        #expect(signer.address == "0xABCDEF1234567890")
        #expect(signer.type == .externalWallet)
    }

    @Test("ExternalWalletSignerData decoding with wrong type throws error")
    func testExternalWalletSignerDataDecodingWrongType() {
        let json = """
        {"type": "api-key", "address": "0xABCDEF1234567890"}
        """

        let data = json.data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(ExternalWalletSignerData.self, from: data)
        }
    }

    // MARK: - ApiKeySignerData Tests

    @Test("ApiKeySignerData initialization")
    func testApiKeySignerDataInit() {
        let signer = ApiKeySignerData()

        #expect(signer.type == .apiKey)
        #expect(signer.locatorId == "api-key")
    }

    @Test("ApiKeySignerData JSON encoding")
    func testApiKeySignerDataEncoding() throws {
        let signer = ApiKeySignerData()

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(signer)
        let json = String(data: data, encoding: .utf8)!

        let expectedJSON = """
        {"type":"api-key"}
        """

        #expect(json == expectedJSON)
    }

    @Test("ApiKeySignerData JSON decoding")
    func testApiKeySignerDataDecoding() throws {
        let json = """
        {"type": "api-key"}
        """

        let data = json.data(using: .utf8)!
        let signer = try JSONDecoder().decode(ApiKeySignerData.self, from: data)

        #expect(signer.type == .apiKey)
        #expect(signer.locatorId == "api-key")
    }

    @Test("ApiKeySignerData decoding with wrong type throws error")
    func testApiKeySignerDataDecodingWrongType() {
        let json = """
        {"type": "passkey"}
        """

        let data = json.data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(ApiKeySignerData.self, from: data)
        }
    }

    // MARK: - PasskeySignerData Tests

    @Test("PasskeySignerData initialization")
    func testPasskeySignerDataInit() {
        let id = "cWtP7gmZbd98HbKUuGXx5Q"
        let name = "hgranger"
        let publicKey = PasskeySignerData.PublicKey(
            x: "38035223810536273945556366218149112558607829411547667975304293530457502824247",
            y: "91117823763706733837104303008228095481082989039135234750508288790583476078729"
        )

        let signer = PasskeySignerData(id: id, name: name, publicKey: publicKey)

        #expect(signer.id == id)
        #expect(signer.name == name)
        #expect(signer.publicKey.x == publicKey.x)
        #expect(signer.publicKey.y == publicKey.y)
        #expect(signer.type == .passkey)
        #expect(signer.locatorId == id)
    }

    @Test("PasskeySignerData JSON encoding")
    func testPasskeySignerDataEncoding() throws {
        let id = "cWtP7gmZbd98HbKUuGXx5Q"
        let name = "hgranger"
        let publicKey = PasskeySignerData.PublicKey(
            x: "38035223810536273945556366218149112558607829411547667975304293530457502824247",
            y: "91117823763706733837104303008228095481082989039135234750508288790583476078729"
        )

        let signer = PasskeySignerData(id: id, name: name, publicKey: publicKey)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(signer)
        let json = String(data: data, encoding: .utf8)!

        let expectedJSON = """
        {"id":"\(id)","name":"\(name)","publicKey":{"x":"\(publicKey.x)","y":"\(publicKey.y)"},"type":"passkey"}
        """

        #expect(json == expectedJSON)
    }

    @Test("PasskeySignerData JSON decoding")
    func testPasskeySignerDataDecoding() throws {
        let json = """
        {
            "type": "passkey",
            "id": "cWtP7gmZbd98HbKUuGXx5Q",
            "name": "hgranger",
            "publicKey": {
                "x": "38035223810536273945556366218149112558607829411547667975304293530457502824247",
                "y": "91117823763706733837104303008228095481082989039135234750508288790583476078729"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let signer = try JSONDecoder().decode(PasskeySignerData.self, from: data)

        #expect(signer.id == "cWtP7gmZbd98HbKUuGXx5Q")
        #expect(signer.name == "hgranger")
        #expect(signer.publicKey.x == "38035223810536273945556366218149112558607829411547667975304293530457502824247")
        #expect(signer.publicKey.y == "91117823763706733837104303008228095481082989039135234750508288790583476078729")
        #expect(signer.type == .passkey)
    }

    @Test("PasskeySignerData decoding with wrong type throws error")
    func testPasskeySignerDataDecodingWrongType() {
        let json = """
        {
            "type": "email",
            "id": "cWtP7gmZbd98HbKUuGXx5Q",
            "name": "hgranger",
            "publicKey": {"x": "123", "y": "456"}
        }
        """

        let data = json.data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(PasskeySignerData.self, from: data)
        }
    }

    // MARK: - EmailSignerData Tests

    @Test("EmailSignerData initialization")
    func testEmailSignerDataInit() {
        let email = "user@example.com"
        let signer = EmailSignerData(email: email)

        #expect(signer.email == email)
        #expect(signer.type == .email)
        #expect(signer.locatorId == email)
    }

    @Test("EmailSignerData JSON encoding")
    func testEmailSignerDataEncoding() throws {
        let email = "user@example.com"
        let signer = EmailSignerData(email: email)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(signer)
        let json = String(data: data, encoding: .utf8)!

        let expectedJSON = """
        {"email":"\(email)","type":"email"}
        """

        #expect(json == expectedJSON)
    }

    @Test("EmailSignerData JSON decoding")
    func testEmailSignerDataDecoding() throws {
        let json = """
        {"type": "email", "email": "test@domain.org"}
        """

        let data = json.data(using: .utf8)!
        let signer = try JSONDecoder().decode(EmailSignerData.self, from: data)

        #expect(signer.email == "test@domain.org")
        #expect(signer.type == .email)
    }

    @Test("EmailSignerData decoding with wrong type throws error")
    func testEmailSignerDataDecodingWrongType() {
        let json = """
        {"type": "phone", "email": "test@domain.org"}
        """

        let data = json.data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(EmailSignerData.self, from: data)
        }
    }

    // MARK: - PhoneSignerData Tests

    @Test("PhoneSignerData initialization")
    func testPhoneSignerDataInit() {
        let phone = "+1234567890"
        let signer = PhoneSignerData(phone: phone)

        #expect(signer.phone == phone)
        #expect(signer.type == .phone)
        #expect(signer.locatorId == phone)
    }

    @Test("PhoneSignerData JSON encoding")
    func testPhoneSignerDataEncoding() throws {
        let phone = "+1234567890"
        let signer = PhoneSignerData(phone: phone)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(signer)
        let json = String(data: data, encoding: .utf8)!

        let expectedJSON = """
        {"phone":"\(phone)","type":"phone"}
        """

        #expect(json == expectedJSON)
    }

    @Test("PhoneSignerData JSON decoding")
    func testPhoneSignerDataDecoding() throws {
        let json = """
        {"type": "phone", "phone": "+9876543210"}
        """

        let data = json.data(using: .utf8)!
        let signer = try JSONDecoder().decode(PhoneSignerData.self, from: data)

        #expect(signer.phone == "+9876543210")
        #expect(signer.type == .phone)
    }

    @Test("PhoneSignerData decoding with wrong type throws error")
    func testPhoneSignerDataDecodingWrongType() {
        let json = """
        {"type": "email", "phone": "+9876543210"}
        """

        let data = json.data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(PhoneSignerData.self, from: data)
        }
    }

    // MARK: - Round-trip Tests

    @Test("ExternalWalletSignerData round-trip encoding/decoding")
    func testExternalWalletSignerDataRoundTrip() throws {
        let original = ExternalWalletSignerData(address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ExternalWalletSignerData.self, from: data)

        #expect(decoded.address == original.address)
        #expect(decoded.type == original.type)
        #expect(decoded.locatorId == original.locatorId)
    }

    @Test("ApiKeySignerData round-trip encoding/decoding")
    func testApiKeySignerDataRoundTrip() throws {
        let original = ApiKeySignerData()

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ApiKeySignerData.self, from: data)

        #expect(decoded.type == original.type)
        #expect(decoded.locatorId == original.locatorId)
    }

    @Test("PasskeySignerData round-trip encoding/decoding")
    func testPasskeySignerDataRoundTrip() throws {
        let original = PasskeySignerData(
            id: "abc123",
            name: "testuser",
            publicKey: PasskeySignerData.PublicKey(x: "123456", y: "789012")
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PasskeySignerData.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.publicKey.x == original.publicKey.x)
        #expect(decoded.publicKey.y == original.publicKey.y)
        #expect(decoded.type == original.type)
        #expect(decoded.locatorId == original.locatorId)
    }

    @Test("EmailSignerData round-trip encoding/decoding")
    func testEmailSignerDataRoundTrip() throws {
        let original = EmailSignerData(email: "roundtrip@test.com")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EmailSignerData.self, from: data)

        #expect(decoded.email == original.email)
        #expect(decoded.type == original.type)
        #expect(decoded.locatorId == original.locatorId)
    }

    @Test("PhoneSignerData round-trip encoding/decoding")
    func testPhoneSignerDataRoundTrip() throws {
        let original = PhoneSignerData(phone: "+14155552671")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PhoneSignerData.self, from: data)

        #expect(decoded.phone == original.phone)
        #expect(decoded.type == original.type)
        #expect(decoded.locatorId == original.locatorId)
    }
}
// swiftlint:enable force_unwrapping
