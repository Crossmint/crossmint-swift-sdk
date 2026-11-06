//
//  QuorumApprovalProgressTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 16/10/26.
//

import CrossmintService
import Foundation
import Testing
import TestsUtils

@testable import Wallet

private let QUORUM = SignerLocator.quorum(id: "9f2c6a1e-4b7d-4c3a-9e51-2d8f0b6c7a14")

@Suite("Quorum approval progress", .tags(.unit))
struct QuorumApprovalProgressTests {
    private func awaitingQuorum() throws -> Transaction {
        let response: StellarTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "StellarTransactionAwaitingQuorum",
            bundle: Bundle.module
        )
        return response.toDomain()
    }

    private func decodeApprovals(_ json: String) throws -> Transaction.Approvals {
        try DefaultJSONCoder().decode(Approvals.self, from: Data(json.utf8)).toDomain
    }

    @Test func readsTheThresholdAndTheRemainingApprovals() throws {
        let quorum = try #require(try awaitingQuorum().approvals?.quorums.first)

        #expect(quorum.signer == QUORUM)
        #expect(quorum.threshold == 2)
        #expect(quorum.remaining == 1)
    }

    @Test func listsThePendingAndSubmittedMembersUnderTheirOwnLocators() throws {
        let quorum = try #require(try awaitingQuorum().approvals?.quorums.first)

        #expect(quorum.pendingMembers == [.email("bob@example.com"), .phone("+14155552671")])
        #expect(quorum.submittedMembers == [.email("alice@example.com")])
    }

    @Test func readsAQuorumThatAlreadyApproved() throws {
        let approvals = try decodeApprovals("""
        {
          "pending": [],
          "submitted": [{
            "signer": { "type": "quorum", "locator": "quorum:abc" },
            "quorumApprovals": {
              "threshold": 1, "remaining": 0, "pending": [],
              "submitted": [{
                "member": { "type": "email", "locator": "email:alice@example.com" },
                "message": "m", "signature": "s", "submittedAt": "2026-10-16T10:01:00.000Z"
              }]
            }
          }]
        }
        """)

        let quorum = try #require(approvals.quorums.first)
        #expect(quorum.remaining == 0)
        #expect(quorum.submittedMembers == [.email("alice@example.com")])
    }

    @Test func readsSingleSignerAndQuorumApprovalsSideBySide() throws {
        let approvals = try decodeApprovals("""
        {
          "pending": [
            { "signer": { "type": "email", "locator": "email:carol@example.com" }, "message": "carol" },
            {
              "signer": { "type": "quorum", "locator": "quorum:abc" },
              "quorumApprovals": {
                "threshold": 2, "remaining": 2, "submitted": [],
                "pending": [{ "member": { "type": "email", "locator": "email:alice@example.com" }, "message": "a" }]
              }
            }
          ],
          "submitted": []
        }
        """)

        #expect(approvals.pending.map(\.signer) == ["email:carol@example.com"])
        #expect(approvals.quorums.map(\.signer) == [.quorum(id: "abc")])
    }
}
