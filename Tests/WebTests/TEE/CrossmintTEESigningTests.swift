//
//  CrossmintTEESigningTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 25/09/26.
//

import CrossmintAuth
import CrossmintCommonTypes
import Foundation
import Testing
@testable import Web

@Suite("CrossmintTEE Signing", .tags(.unit))
@MainActor
struct CrossmintTEESigningTests {
    @Test(
        "Signs transaction when device is ready",
        arguments: [
            SignerIdentity.email("test@example.com"),
            SignerIdentity.phone("+15555550123", channel: .sms)
        ]
    )
    func testSignTransactionWhenDeviceReady(identity: SignerIdentity) async throws {
        let fixture = TEETestFixture(identity: identity)
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        fixture.configureReadyDevice()
        fixture.configureSignResponse(signature: "0xsignature123")

        let transaction = CrossmintTEETestHelpers.createTestTransaction()
        let signature = try await fixture.signTransaction(
            transaction: transaction,
            keyType: "keyType",
            encoding: "encoding"
        )

        #expect(signature == "0xsignature123")
        try fixture.verifySignRequest(expectedTransaction: transaction)
    }

    @Test("Signing fails without handshake")
    func testSigningFailsWithoutHandshake() async throws {
        let fixture = TEETestFixture()

        await #expect(throws: CrossmintTEE.Error.handshakeFailed) {
            _ = try await fixture.signTransaction(
                transaction: "test",
                keyType: "keyType",
                encoding: "encoding"
            )
        }
    }

    @Test("Signing fails without JWT")
    func testSigningFailsWithoutJWT() async throws {
        let fixture = TEETestFixture()
        try await fixture.setupHandshake()

        await #expect(throws: CrossmintTEE.Error.jwtRequired) {
            _ = try await fixture.signTransaction(
                transaction: "test",
                keyType: "keyType",
                encoding: "encoding"
            )
        }
    }

    @Test("Handles server error response")
    func testHandlesServerErrorResponse() async throws {
        let fixture = TEETestFixture()
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        fixture.configureErrorResponse(errorMessage: "Server error occurred")

        await #expect(throws: CrossmintTEE.Error.generic("Server error occurred")) {
            _ = try await fixture.signTransaction(
                transaction: "test",
                keyType: "keyType",
                encoding: "encoding"
            )
        }
    }

    @Test("Handles invalid signature response")
    func testHandlesInvalidSignatureResponse() async throws {
        let fixture = TEETestFixture()
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        fixture.configureReadyDevice()

        let signResponse = CrossmintTEETestHelpers.createNonCustodialSignResponse(
            signature: "",
            status: .success
        )
        fixture.webProxy.configureResponse(for: NonCustodialSignResponse.self, response: signResponse)

        await #expect(throws: CrossmintTEE.Error.invalidSignature) {
            _ = try await fixture.signTransaction(
                transaction: "test",
                keyType: "keyType",
                encoding: "encoding"
            )
        }
    }

    @Test("Rejects non-hex signature when hex encoding was requested")
    func testRejectsNonHexSignatureForHexEncoding() async throws {
        let fixture = TEETestFixture()
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        fixture.configureReadyDevice()
        fixture.configureSignResponse(signature: "not-a-hex-ecdsa-signature")

        await #expect(throws: CrossmintTEE.Error.invalidSignature) {
            _ = try await fixture.signTransaction(
                transaction: CrossmintTEETestHelpers.createTestTransaction(),
                keyType: "secp256k1",
                encoding: "hex"
            )
        }
    }

    @Test("Returns hex signature verbatim even when its bytes decode as UTF-8")
    func testHexSignatureIsNotDecodedAsUTF8() async throws {
        let fixture = TEETestFixture()
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        fixture.configureReadyDevice()
        // 0x48656c6c6f decodes to the UTF-8 string "Hello"; the signature
        // must be passed through verbatim, not decoded (regression for WAL-11310).
        fixture.configureSignResponse(signature: "0x48656c6c6f")

        let signature = try await fixture.signTransaction(
            transaction: CrossmintTEETestHelpers.createTestTransaction(),
            keyType: "secp256k1",
            encoding: "hex"
        )

        #expect(signature == "0x48656c6c6f")
    }

    @Test("Throws when the frame reports an error status for the sign request")
    func testThrowsOnSignErrorStatus() async throws {
        let fixture = TEETestFixture()
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        fixture.configureReadyDevice()

        let signResponse = CrossmintTEETestHelpers.createNonCustodialSignResponse(
            signature: "",
            status: .error,
            errorMessage: "Signing failed in frame"
        )
        fixture.webProxy.configureResponse(for: NonCustodialSignResponse.self, response: signResponse)

        await #expect(throws: CrossmintTEE.Error.generic("Signing failed in frame")) {
            _ = try await fixture.signTransaction(
                transaction: "test",
                keyType: "keyType",
                encoding: "encoding"
            )
        }
    }
}
