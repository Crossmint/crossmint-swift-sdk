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

struct RejectedSignResponse: Sendable, CustomTestStringConvertible {
    let testDescription: String
    let signature: String
    let status: ResponseStatus
    let errorMessage: String?
    let encoding: String
    let expectedError: CrossmintTEE.Error
}

@Suite("CrossmintTEE Signing", .tags(.unit))
@MainActor
struct CrossmintTEESigningTests {
    @Test(arguments: [
        SignerIdentity.email("test@example.com"),
        SignerIdentity.phone("+15555550123", channel: .sms)
    ])
    func signsTransactionWhenDeviceIsReady(identity: SignerIdentity) async throws {
        let fixture = TEETestFixture(identity: identity)
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        fixture.configureReadyDevice()
        fixture.configureSignResponse(signature: "0xsignature123")

        let transaction = CrossmintTEETestHelpers.createTestTransaction()
        let signature = try await fixture.signTransaction(transaction: transaction)

        #expect(signature == "0xsignature123")
        try fixture.verifySignRequest(expectedTransaction: transaction)
    }

    @Test func failsToSignWithoutHandshake() async throws {
        let fixture = TEETestFixture()

        await #expect(throws: CrossmintTEE.Error.handshakeFailed) {
            _ = try await fixture.signTransaction(transaction: "test")
        }
    }

    @Test func failsToSignWithoutJWT() async throws {
        let fixture = TEETestFixture()
        try await fixture.setupHandshake()

        await #expect(throws: CrossmintTEE.Error.jwtRequired) {
            _ = try await fixture.signTransaction(transaction: "test")
        }
    }

    @Test func surfacesStatusErrorFromFrame() async throws {
        let fixture = TEETestFixture()
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        fixture.configureErrorResponse(errorMessage: "Server error occurred")

        await #expect(throws: CrossmintTEE.Error.generic("Server error occurred")) {
            _ = try await fixture.signTransaction(transaction: "test")
        }
    }

    @Test(arguments: [
        RejectedSignResponse(
            testDescription: "empty signature",
            signature: "",
            status: .success,
            errorMessage: nil,
            encoding: "encoding",
            expectedError: .invalidSignature
        ),
        RejectedSignResponse(
            testDescription: "non-hex signature for a hex request",
            signature: "not-a-hex-ecdsa-signature",
            status: .success,
            errorMessage: nil,
            encoding: "hex",
            expectedError: .invalidSignature
        ),
        RejectedSignResponse(
            testDescription: "error status",
            signature: "",
            status: .error,
            errorMessage: "Signing failed in frame",
            encoding: "encoding",
            expectedError: .generic("Signing failed in frame")
        )
    ])
    func rejectsInvalidSignResponse(_ response: RejectedSignResponse) async throws {
        let fixture = TEETestFixture()
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        fixture.configureReadyDevice()
        let signResponse = CrossmintTEETestHelpers.createNonCustodialSignResponse(
            signature: response.signature,
            status: response.status,
            errorMessage: response.errorMessage
        )
        fixture.webProxy.configureResponse(for: NonCustodialSignResponse.self, response: signResponse)

        await #expect(throws: response.expectedError) {
            _ = try await fixture.signTransaction(
                transaction: CrossmintTEETestHelpers.createTestTransaction(),
                keyType: "secp256k1",
                encoding: response.encoding
            )
        }
    }

    @Test func returnsHexSignatureVerbatimWhenItsBytesDecodeAsUTF8() async throws {
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
}
