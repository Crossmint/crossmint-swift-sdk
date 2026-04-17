import CrossmintCommonTypes
import Foundation
import Testing
@testable import Wallet

struct AdminSignerRequestApiModelTests {
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = .sortedKeys
        return e
    }()

    private func encode(_ data: any AdminSignerData) throws -> String {
        let raw = try encoder.encode(AdminSignerRequestApiModel(data))
        return String(bytes: raw, encoding: .utf8) ?? ""
    }

    @Test func emailSignerEncodesCorrectly() throws {
        let json = try encode(EmailSignerData(email: "user@example.com"))
        #expect(json == #"{"email":"user@example.com","type":"email"}"#)
    }

    @Test func phoneSignerEncodesCorrectly() throws {
        let json = try encode(PhoneSignerData(phone: "+15551234567"))
        #expect(json == #"{"phone":"+15551234567","type":"phone"}"#)
    }

    @Test func externalWalletSignerEncodesCorrectly() throws {
        let json = try encode(ExternalWalletSignerData(address: "0xABC"))
        #expect(json == #"{"address":"0xABC","type":"external-wallet"}"#)
    }

    @Test func serverSignerEncodesCorrectly() throws {
        let json = try encode(ServerSignerData(address: "0xSERVER"))
        #expect(json == #"{"address":"0xSERVER","type":"server"}"#)
    }

    @Test func apiKeySignerEncodesCorrectly() throws {
        let json = try encode(ApiKeySignerData())
        #expect(json == #"{"type":"api-key"}"#)
    }

    @Test func apiKeySignerWithAddressEncodesCorrectly() throws {
        let json = try encode(ApiKeySignerData(address: "0xABC"))
        #expect(json == #"{"address":"0xABC","type":"api-key"}"#)
    }

    @Test func passkeySignerEncodesCorrectly() throws {
        let key = PasskeySignerData.PublicKey(x: "123", y: "456")
        let json = try encode(PasskeySignerData(id: "pk-id", name: "alice", publicKey: key))
        #expect(json == #"{"id":"pk-id","name":"alice","publicKey":{"x":"123","y":"456"},"type":"passkey"}"#)
    }

    @Test func passkeySignerWithValidatorVersionEncodesCorrectly() throws {
        let key = PasskeySignerData.PublicKey(x: "1", y: "2")
        let signer = PasskeySignerData(id: "pk-id", name: "bob", publicKey: key, validatorContractVersion: "v2")
        let json = try encode(signer)
        let expected = #"{"id":"pk-id","name":"bob","publicKey":{"x":"1","y":"2"}"# +
            #","type":"passkey","validatorContractVersion":"v2"}"#
        #expect(json == expected)
    }
}
