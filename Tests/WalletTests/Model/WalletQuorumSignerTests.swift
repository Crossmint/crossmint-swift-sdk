//
//  WalletQuorumSignerTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 16/10/26.
//

import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils

@testable import Wallet

private let QUORUM_ID = "9f2c6a1e-4b7d-4c3a-9e51-2d8f0b6c7a14"

@Suite("Wallet with a quorum signer", .tags(.unit))
struct WalletQuorumSignerTests {
    private func makeStellarWallet() throws -> StellarWallet {
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletStellarQuorum",
            bundle: Bundle.module
        )
        return try StellarWallet(
            smartWalletService: MockSmartWalletService(),
            signer: nil,
            baseModel: baseModel,
            stellarChain: .stellar
        )
    }

    @Test func loadsAWalletWhoseOnlyRecoveryMethodIsAQuorum() throws {
        let wallet = try makeStellarWallet()

        let quorum = try #require(wallet.config.recovery as? QuorumSignerData)

        #expect(quorum.locator == "quorum:\(QUORUM_ID)")
        #expect(quorum.threshold == 2)
        #expect(wallet.config.recoveryMethodsWithStatus.map(\.status) == [.active])
    }

    @Test func keepsTheSupportedMembersInOrder() throws {
        let wallet = try makeStellarWallet()

        let quorum = try #require(wallet.config.recovery as? QuorumSignerData)

        #expect(quorum.members.map(\.locator) == [
            "email:alice@example.com",
            "email:bob@example.com",
            "phone:+14155552671"
        ])
    }
}
