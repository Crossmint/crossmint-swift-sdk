//
//  QuorumAsSignerTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 21/10/26.
//

import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils

@testable import Wallet

private let SIGNER_QUORUM = SignerLocator.quorum(id: "0b8e7d6c-5a4f-4e3d-8c2b-1a0f9e8d7c6b")

private struct SentSignerConfig: Decodable {
    struct Entry: Decodable {
        let signer: Signer
    }

    struct Signer: Decodable {
        let type: String
        let threshold: Int
        let members: [Member]
    }

    struct Member: Decodable {
        let type: String
        let email: String?
    }

    let delegatedSigners: [Entry]?
}

@Suite("Quorum as a signer", .tags(.unit))
struct QuorumAsSignerTests {
    private let walletService = MockSmartWalletService()

    private func makeWallet(fileName: String, signer: MockSigner?) throws -> StellarWallet {
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(fileName: fileName, bundle: Bundle.module)
        walletService.getWalletResult = baseModel
        return try StellarWallet(
            smartWalletService: walletService,
            signer: signer,
            baseModel: baseModel,
            stellarChain: .stellar
        )
    }

    @Test func sendsAQuorumSignerWhenCreatingAWallet() async throws {
        let url = try #require(Bundle.module.url(forResource: "WalletStellarQuorum", withExtension: "json"))
        walletService.createWalletFixture = try Data(contentsOf: url)
        let wallets = DefaultCrossmintWallets(
            service: walletService,
            secureWalletStorage: StubSecureWalletStorage(),
            deviceSignerKeyStorage: MockDeviceSignerKeyStorage()
        )

        _ = try await wallets.createWallet(
            chain: Chain("stellar"),
            recoveryMethods: [MockSigner(email: "alice@example.com")],
            signers: [.quorum(threshold: 2, members: [.email("carol@example.com"), .email("dave@example.com")])],
            options: nil
        )

        let body = try JSONEncoder().encode(try #require(walletService.lastCreateWalletParams?.config))
        let config = try JSONDecoder().decode(SentSignerConfig.self, from: body)
        let quorum = try #require(config.delegatedSigners?.first?.signer)
        #expect(quorum.type == "quorum")
        #expect(quorum.threshold == 2)
        #expect(quorum.members.map(\.type) == ["email", "email"])
        #expect(quorum.members.map(\.email) == ["carol@example.com", "dave@example.com"])
    }

    @Test func addsAQuorumSignerAndReadsItsMembers() async throws {
        let wallet = try makeWallet(
            fileName: "WalletStellarRecoveryMethods",
            signer: MockSigner(email: "alice@example.com")
        )
        walletService.getWalletResult = try GetFromFile.getModelFrom(
            fileName: "WalletStellarQuorum",
            bundle: Bundle.module
        )

        try await wallet.addSigner(
            .quorum(threshold: 2, members: [.email("carol@example.com"), .email("dave@example.com")])
        )
        try await wallet.useSigner(.email("carol@example.com"))

        let sent = walletService.lastAddSignerEntry?.signer
        #expect(sent == .quorum(threshold: 2, members: [
            .locator(.email("carol@example.com")),
            .locator(.email("dave@example.com"))
        ]))
        #expect(wallet.selectedQuorum == SIGNER_QUORUM)
    }

    @Test func rejectsAQuorumSignerWithADeviceMemberBeforeCallingTheApi() async throws {
        let wallet = try makeWallet(
            fileName: "WalletStellarRecoveryMethods",
            signer: MockSigner(email: "alice@example.com")
        )

        await #expect(throws: WalletError.self) {
            try await wallet.addSigner(.quorum(threshold: 1, members: [.device, .email("carol@example.com")]))
        }
        #expect(walletService.addSignerCallCount == 0)
    }

    @Test func listsTheThresholdAndMembersOfAQuorumSigner() async throws {
        let wallet = try makeWallet(fileName: "WalletStellarQuorum", signer: nil)

        let signers = try await wallet.signers()

        let quorum = try #require(signers.first { $0.locator == SIGNER_QUORUM }?.quorum)
        #expect(quorum.threshold == 2)
        #expect(quorum.members == [.email("carol@example.com"), .email("dave@example.com")])
    }

    @Test func doesNotApproveSignerChangesForAQuorumSigner() async throws {
        let wallet = try makeWallet(fileName: "WalletStellarQuorum", signer: nil)

        await #expect(throws: WalletError.self) {
            try await wallet.useRecoveryMethod(.email("carol@example.com"))
        }
    }
}
