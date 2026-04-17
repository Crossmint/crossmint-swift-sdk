import Testing

@testable import CrossmintCommonTypes

struct AdminSignerDataTests {

    // MARK: - ExternalWalletSignerData

    @Test("ExternalWalletSignerData initialization")
    func testExternalWalletSignerDataInit() {
        let address = "0x1234567890123456789012345678901234567890"
        let signer = ExternalWalletSignerData(address: address)

        #expect(signer.address == address)
        #expect(signer.type == .externalWallet)
        #expect(signer.locatorId == address)
        #expect(signer.locator == "external-wallet:\(address)")
    }

    // MARK: - ApiKeySignerData

    @Test("ApiKeySignerData initialization")
    func testApiKeySignerDataInit() {
        let signer = ApiKeySignerData()

        #expect(signer.type == .apiKey)
        #expect(signer.locatorId == "api-key")
    }

    // MARK: - PasskeySignerData

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
        #expect(signer.locator == "passkey:\(id)")
    }

    // MARK: - EmailSignerData

    @Test("EmailSignerData initialization")
    func testEmailSignerDataInit() {
        let email = "user@example.com"
        let signer = EmailSignerData(email: email)

        #expect(signer.email == email)
        #expect(signer.type == .email)
        #expect(signer.locatorId == email)
        #expect(signer.locator == "email:\(email)")
    }

    // MARK: - PhoneSignerData

    @Test("PhoneSignerData initialization")
    func testPhoneSignerDataInit() {
        let phone = "+1234567890"
        let signer = PhoneSignerData(phone: phone)

        #expect(signer.phone == phone)
        #expect(signer.type == .phone)
        #expect(signer.locatorId == phone)
        #expect(signer.locator == "phone:\(phone)")
    }

    // MARK: - ServerSignerData

    @Test("ServerSignerData initialization")
    func testServerSignerDataInit() {
        let address = "0xServerAddress"
        let signer = ServerSignerData(address: address)

        #expect(signer.address == address)
        #expect(signer.type == .server)
        #expect(signer.locatorId == address)
        #expect(signer.locator == "server:\(address)")
    }
}
