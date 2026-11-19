//
//  DefaultTransferServiceTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 18/11/26.
//

import CrossmintCommonTypes
import CrossmintService
import Foundation
import Testing
import TestsUtils

@testable import Wallet

@Suite("Token transfer requests", .tags(.unit))
struct DefaultTransferServiceTests {
    @Test
    func sendsTheApprovingMembersOfASolanaTransferAndReadsTheReply() async throws {
        let router = try router(respondingWith: "SolanaQuorumTransferAwaitingApproval")

        let transaction = try await transferService(router).transferToken(quorumTransfer)

        #expect(transaction.toDomain().status == .awaitingApproval)
        let body = try #require(router.lastRequest?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["approvingMembers"] as? [String] == ["email:alice@example.com", "email:bob@example.com"])
    }

    private let quorumTransfer = TransferTokenRequest(
        chainType: .solana,
        tokenLocator: "solana:usdc",
        recipient: "J22yK97UmV7CBa1uPkjohLWHXugx6vsaS3hUaPUPbMfu",
        amount: "1",
        signer: "quorum:9f2c6a1e-4b7d-4c3a-9e51-2d8f0b6c7a14",
        approvingMembers: ["email:alice@example.com", "email:bob@example.com"]
    )

    private func router(respondingWith fixture: String) throws -> HTTPFixtureRouter {
        let response = try #require(Bundle.module.url(forResource: fixture, withExtension: "json"))
        let router = HTTPFixtureRouter()
        router.respond(body: try Data(contentsOf: response))
        return router
    }

    private func transferService(_ router: HTTPFixtureRouter) throws -> DefaultTransferService {
        DefaultTransferService(
            crossmintService: DefaultCrossmintService(
                apiKey: try ApiKey(key: "ck_staging_test123"),
                appIdentifier: "com.crossmint.tests",
                httpClient: router.client
            ),
            jsonCoder: DefaultJSONCoder()
        )
    }
}
