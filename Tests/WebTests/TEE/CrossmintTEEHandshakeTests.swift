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
    @Test(arguments: [
        (true, "https://signers.crossmint.com?deviceStorage=memory"),
        (false, "https://staging.signers.crossmint.com?deviceStorage=memory")
    ])
    func completesHandshakeWithEnvironmentFrame(productionEnvironment: Bool, expectedURL: String) async throws {
        let fixture = TEETestFixture(isProductionEnvironment: productionEnvironment)
        try await fixture.setupHandshake(verificationId: "test123")

        try fixture.verifyHandshakeCompleted(verificationId: "test123")
        #expect(fixture.webProxy.loadedURLs.map(\.absoluteString) == [expectedURL])
    }

    @Test func retriesHandshakeThreeTimesOnTimeout() async throws {
        let fixture = TEETestFixture()

        await #expect(throws: CrossmintTEE.Error.handshakeFailed) {
            try await fixture.tee.load()
        }

        #expect(fixture.webProxy.sentMessages(ofType: HandshakeRequest.self).count == 3)
    }

    @Test func requiresNewHandshakeAfterReset() async throws {
        let fixture = TEETestFixture()
        try await fixture.setupHandshake()

        fixture.tee.resetState()
        fixture.webProxy.clearResponse(for: HandshakeResponse.self)

        #expect(fixture.webProxy.resetCount == 1)

        await #expect(throws: CrossmintTEE.Error.handshakeFailed) {
            _ = try await fixture.signTransaction(transaction: "test")
        }
    }

    @Test func failsToLoadWhenWebViewIsUnavailable() async throws {
        let fixture = TEETestFixture()
        fixture.webProxy.shouldThrowOnLoad = true

        await #expect(throws: CrossmintTEE.Error.urlNotAvailable) {
            try await fixture.tee.load()
        }
    }
}
