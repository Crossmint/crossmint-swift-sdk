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
