import Foundation
import Testing
@testable import Web

@Suite("Signer Request Messages", .tags(.unit))
struct SignerRequestMessagesTests {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private func encode<T: Encodable>(_ value: T) throws -> String {
        let raw = try encoder.encode(value)
        return String(bytes: raw, encoding: .utf8) ?? ""
    }

    @Test func getStatusEncodesTheRecoveryMethodAuthId() throws {
        let request = GetStatusRequest(jwt: "test-jwt", apiKey: "test-api-key", authId: "email:user@example.com")
        let json = try encode(request.data)
        let expected = #"{"authData":{"apiKey":"test-api-key","jwt":"test-jwt"},"#
            + #""data":{"authId":"email:user@example.com"}}"#
        #expect(json == expected)
    }

    @Test func getStatusOmitsDataWhenNoAuthIdIsGiven() throws {
        let request = GetStatusRequest(jwt: "test-jwt", apiKey: "test-api-key")
        let json = try encode(request.data)
        #expect(json == #"{"authData":{"apiKey":"test-api-key","jwt":"test-jwt"}}"#)
    }

    @Test func signEncodesTheRecoveryMethodAuthId() throws {
        let request = NonCustodialSignRequest(
            jwt: "test-jwt",
            apiKey: "test-api-key",
            messageBytes: "message",
            keyType: "ed25519",
            encoding: "base58",
            authId: "phone:+15551234567"
        )
        let json = try encode(request.data.data)
        #expect(
            json == #"{"authId":"phone:+15551234567","bytes":"message","encoding":"base58","keyType":"ed25519"}"#
        )
    }

    @Test func signOmitsAuthIdWhenNoneIsGiven() throws {
        let request = NonCustodialSignRequest(
            jwt: "test-jwt",
            apiKey: "test-api-key",
            messageBytes: "message",
            keyType: "ed25519",
            encoding: "base58"
        )
        let json = try encode(request.data.data)
        #expect(json == #"{"bytes":"message","encoding":"base58","keyType":"ed25519"}"#)
    }
}
