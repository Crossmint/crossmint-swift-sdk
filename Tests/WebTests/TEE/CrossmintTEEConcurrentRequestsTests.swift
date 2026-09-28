//
//  CrossmintTEEConcurrentRequestsTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 25/09/26.
//

import CrossmintAuth
import CrossmintCommonTypes
import Foundation
import Testing
@testable import Web

@Suite("CrossmintTEE Concurrent Requests", .tags(.unit))
@MainActor
struct CrossmintTEEConcurrentRequestsTests {
    @Test func cancelsSecondDuplicateRequestWithoutAffectingFirst() async throws {
        let fixture = TEETestFixture()
        await fixture.setupAuthentication()

        let handshakeResponse = CrossmintTEETestHelpers.createHandshakeResponse(verificationId: "test123")
        fixture.webProxy.holdResponse(for: HandshakeResponse.self, response: handshakeResponse)
        fixture.configureReadyDevice()
        fixture.configureSignResponse(signature: "0xsignature_first")

        let transaction = CrossmintTEETestHelpers.createTestTransaction()
        let firstTask = Task {
            try await fixture.signTransaction(transaction: transaction)
        }
        let secondTask = Task {
            try await fixture.signTransaction(transaction: transaction)
        }
        await fixture.webProxy.waitUntilResponseIsAwaited(for: HandshakeResponse.self)

        secondTask.cancel()
        await #expect(throws: CrossmintTEE.Error.generic("Task was cancelled")) {
            _ = try await secondTask.value
        }

        fixture.webProxy.releaseResponse(for: HandshakeResponse.self)
        #expect(try await firstTask.value == "0xsignature_first")
    }

    @Test func resolvesEveryIdenticalRequestQueuedDuringHandshake() async throws {
        let fixture = TEETestFixture()
        await fixture.setupAuthentication()

        let handshakeResponse = CrossmintTEETestHelpers.createHandshakeResponse(verificationId: "test123")
        fixture.webProxy.holdResponse(for: HandshakeResponse.self, response: handshakeResponse)
        fixture.configureReadyDevice()
        fixture.configureSignResponse(signature: "0xsignature_all")

        let transaction = CrossmintTEETestHelpers.createTestTransaction()
        let signTasks = (0..<3).map { _ in
            Task {
                try await fixture.signTransaction(transaction: transaction)
            }
        }
        await fixture.webProxy.waitUntilResponseIsAwaited(for: HandshakeResponse.self)
        fixture.webProxy.releaseResponse(for: HandshakeResponse.self)

        for signTask in signTasks {
            #expect(try await signTask.value == "0xsignature_all")
        }
        #expect(fixture.webProxy.sentMessages(ofType: NonCustodialSignRequest.self).count == 3)
    }
}
