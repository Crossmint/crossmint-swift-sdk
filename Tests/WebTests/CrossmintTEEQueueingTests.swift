import CrossmintAuth
import CrossmintCommonTypes
import Foundation
import Testing
@testable import Web

@Suite("CrossmintTEE Queueing and Recovery", .tags(.unit))
struct CrossmintTEEQueueingTests {
@Suite("Concurrent Requests")
@MainActor
struct ConcurrentRequestsTests {
    @Test("Cancelling second duplicate request does not affect first")
    func testCancellingSecondDuplicateRequestDoesNotAffectFirst() async throws {
        let fixture = TEETestFixture()
        await fixture.setupAuthentication()

        let handshakeResponse = CrossmintTEETestHelpers.createHandshakeResponse(verificationId: "test123")
        fixture.webProxy.configureResponseWithDelay(
            for: HandshakeResponse.self,
            response: handshakeResponse,
            delay: 0.3
        )
        fixture.configureReadyDevice()
        fixture.configureSignResponse(signature: "0xsignature_first")

        let transaction = CrossmintTEETestHelpers.createTestTransaction()

        let task1 = Task {
            try await fixture.signTransaction(
                transaction: transaction,
                keyType: "keyType",
                encoding: "encoding"
            )
        }

        await Task.yield()

        let task2 = Task {
            try await fixture.signTransaction(
                transaction: transaction,
                keyType: "keyType",
                encoding: "encoding"
            )
        }

        await Task.yield()

        task2.cancel()

        let result1 = await task1.result
        let result2 = await task2.result

        switch result1 {
        case .success(let signature):
            #expect(signature == "0xsignature_first")
        case .failure(let error):
            Issue.record("First task should succeed but failed with: \(error)")
        }

        switch result2 {
        case .success:
            Issue.record("Second task should have been cancelled")
        case .failure:
            break
        }
    }

    @Test("Multiple identical requests process independently")
    func testMultipleIdenticalRequestsProcessIndependently() async throws {
        let fixture = TEETestFixture()
        await fixture.setupAuthentication()

        let handshakeResponse = CrossmintTEETestHelpers.createHandshakeResponse(verificationId: "test123")
        fixture.webProxy.configureResponseWithDelay(
            for: HandshakeResponse.self,
            response: handshakeResponse,
            delay: 0.2
        )
        fixture.configureReadyDevice()
        fixture.configureSignResponse(signature: "0xsignature_all")

        let transaction = CrossmintTEETestHelpers.createTestTransaction()

        let task1 = Task {
            try await fixture.signTransaction(
                transaction: transaction,
                keyType: "keyType",
                encoding: "encoding"
            )
        }

        let task2 = Task {
            try await fixture.signTransaction(
                transaction: transaction,
                keyType: "keyType",
                encoding: "encoding"
            )
        }

        let task3 = Task {
            try await fixture.signTransaction(
                transaction: transaction,
                keyType: "keyType",
                encoding: "encoding"
            )
        }

        let results = await [task1.result, task2.result, task3.result]

        var successCount = 0
        for result in results {
            switch result {
            case .success(let signature):
                #expect(signature == "0xsignature_all")
                successCount += 1
            case .failure(let error):
                Issue.record("Task failed unexpectedly: \(error)")
            }
        }

        #expect(successCount == 3)
    }
}

@Suite("Recovery")
@MainActor
struct RecoveryTests {
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
}
