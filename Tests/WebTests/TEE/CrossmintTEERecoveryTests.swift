//
//  CrossmintTEERecoveryTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 10/09/26.
//

import CrossmintAuth
import CrossmintCommonTypes
import Foundation
import Testing
@testable import Web

@Suite("Recovery", .tags(.unit))
@MainActor
struct CrossmintTEERecoveryTests {
    @Test("Recovers and re-handshakes after web content process termination")
    func testRecoversAfterWebContentProcessTermination() async throws {
        let fixture = TEETestFixture()
        await fixture.setupAuthentication()
        try await fixture.setupHandshake(verificationId: "test123")

        #expect(fixture.webProxy.loadedURLs.count == 1)
        #expect(fixture.webProxy.sentMessages(ofType: HandshakeRequest.self).count == 1)

        fixture.webProxy.onWebContentProcessTerminated()
        await fixture.tee.recoveryTask?.value

        #expect(fixture.webProxy.loadedURLs.count == 2)
        #expect(fixture.webProxy.sentMessages(ofType: HandshakeRequest.self).count == 2)

        fixture.configureReadyDevice()
        fixture.configureSignResponse(signature: "0xrecovered")

        let transaction = CrossmintTEETestHelpers.createTestTransaction()
        let signature = try await fixture.signTransaction(
            transaction: transaction,
            keyType: "keyType",
            encoding: "encoding"
        )

        #expect(signature == "0xrecovered")
    }

    @Test("resetState cancels an in-flight recovery and frees it to start again")
    func testResetStateCancelsInFlightRecovery() async throws {
        let fixture = TEETestFixture()
        await fixture.setupAuthentication()
        try await fixture.setupHandshake(verificationId: "test123")

        fixture.webProxy.onWebContentProcessTerminated()
        #expect(fixture.tee.recoveryTask != nil)

        fixture.tee.resetState()
        #expect(fixture.tee.recoveryTask == nil)

        fixture.webProxy.onWebContentProcessTerminated()
        #expect(fixture.tee.recoveryTask != nil)
    }
}
