//
//  CrossmintTEEHandshakeTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 25/09/26.
//

import CrossmintAuth
import CrossmintCommonTypes
import Foundation
import Testing
@testable import Web

@Suite("CrossmintTEE Handshake", .tags(.unit))
@MainActor
struct CrossmintTEEHandshakeTests {
    @Test("Successfully completes handshake on first attempt")
    func testSuccessfulHandshakeFirstAttempt() async throws {
        let fixture = TEETestFixture()
        try await fixture.setupHandshake(verificationId: "test123")

        fixture.verifyHandshakeCompleted(verificationId: "test123")

        #expect(fixture.webProxy.loadedURLs.count == 1)
        #expect(fixture.webProxy.loadedURLs.first?.absoluteString.contains("signers.crossmint.com") == true)
    }

    @Test("Retries handshake on timeout up to 3 times")
    func testHandshakeRetryOnTimeout() async throws {
        let fixture = TEETestFixture()

        await #expect(throws: CrossmintTEE.Error.handshakeFailed) {
            try await fixture.tee.load()
        }

        let handshakeRequests = fixture.webProxy.sentMessages(ofType: HandshakeRequest.self)
        #expect(handshakeRequests.count == 3)
    }

    @Test("Resets state correctly")
    func testResetState() async throws {
        let fixture = TEETestFixture()
        try await fixture.setupHandshake()

        fixture.tee.resetState()
        fixture.webProxy.clearResponse(for: HandshakeResponse.self)

        #expect(fixture.webProxy.resetCount == 1)

        await #expect(throws: CrossmintTEE.Error.handshakeFailed) {
            _ = try await fixture.signTransaction(
                transaction: "test",
                keyType: "keyType",
                encoding: "encoding"
            )
        }
    }

    @Test("Load fails when URL is not available")
    func testLoadFailsWhenURLNotAvailable() async throws {
        let fixture = TEETestFixture()

        fixture.webProxy.shouldThrowOnLoad = true
        fixture.webProxy.loadError = WebViewError.webViewNotAvailable

        await #expect(throws: CrossmintTEE.Error.urlNotAvailable) {
            try await fixture.tee.load()
        }
    }
}
