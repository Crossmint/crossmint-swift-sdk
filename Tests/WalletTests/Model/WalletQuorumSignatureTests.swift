//
//  WalletQuorumSignatureTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 06/11/26.
//

import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils

@testable import Wallet

private let SIGNATURE_ID = "5d1e0c84-2f6b-4b8e-9a7d-3c2e1f0a9b86"

@Suite("Wallet quorum signatures", .tags(.unit))
struct WalletQuorumSignatureTests {
    private func makeWallet(walletService: MockSmartWalletService) throws -> EVMWallet {
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(fileName: "WalletEVMQuorum", bundle: Bundle.module)
        walletService.getWalletResult = baseModel
        return try EVMWallet(
            smartWalletService: walletService,
            signer: nil,
            baseModel: baseModel,
            evmChain: .baseSepolia
        )
    }

    private func signature(_ fileName: String) throws -> MessageSignatureResponse {
        try GetFromFile.getModelFrom(fileName: fileName, bundle: Bundle.module)
    }

    @Test func createsAMessageSignatureForTheQuorumWithoutSigningIt() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeWallet(walletService: walletService)
        let member = MockSigner(email: "bob@example.com")
        wallet.selectedSigner = member
        walletService.createSignatureResult = try signature("SignatureAwaitingQuorum")

        let result = try await wallet.signMessage("Hello, Crossmint!")

        #expect(result.id == SIGNATURE_ID)
        #expect(result.signature == nil)
        #expect(member.signedMessages.isEmpty)
        #expect(walletService.approveSignatureCallCount == 0)
    }

    @Test func preparesASignatureWithoutSigningIt() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeWallet(walletService: walletService)
        walletService.createSignatureResult = try GetFromFile.getModelFrom(
            fileName: "CreateSignatureAwaitingApproval",
            bundle: Bundle.module
        ) as TypedDataSignatureResponse

        let result = try await wallet.signMessage(
            "Hello, Crossmint!",
            signer: EmailSignerData(email: "alice@example.com"),
            prepareOnly: true
        )

        #expect(result.signature == nil)
        #expect(walletService.approveSignatureCallCount == 0)
    }

    @Test func approvesASignatureAsTheMemberThisDeviceHolds() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeWallet(walletService: walletService)
        let member = MockSigner(email: "bob@example.com")
        member.approvalsResult = [.keypair(signer: "email:bob@example.com", signature: "bob-signature")]
        wallet.selectedSigner = member
        walletService.fetchSignatureResults = [
            try signature("SignatureAwaitingQuorum"),
            try signature("SignatureQuorumApproved")
        ]

        let result = try await wallet.approve(signatureId: SIGNATURE_ID)

        #expect(member.signedMessages == ["bob-message"])
        #expect(walletService.approveSignatureCallCount == 1)
        #expect(result.signature == "0xwallet-signature")
    }

    @Test func throwsWhenTheApprovedSignatureFails() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeWallet(walletService: walletService)
        let member = MockSigner(email: "bob@example.com")
        member.approvalsResult = [.keypair(signer: "email:bob@example.com", signature: "bob-signature")]
        wallet.selectedSigner = member
        walletService.fetchSignatureResults = [
            try signature("SignatureAwaitingQuorum"),
            try signature("SignatureFailed")
        ]

        await #expect {
            _ = try await wallet.approve(signatureId: SIGNATURE_ID)
        } throws: { error in
            guard case .approvalFailed = error as? SignatureError else { return false }
            return true
        }
    }

    @Test func returnsWithoutASignatureWhileOtherMembersMustApprove() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeWallet(walletService: walletService)
        let outsider = MockSigner(email: "carol@example.com")
        wallet.selectedSigner = outsider
        walletService.fetchSignatureResults = [
            try signature("SignatureAwaitingQuorum"),
            try signature("SignatureAwaitingQuorum")
        ]

        let result = try await wallet.approve(signatureId: SIGNATURE_ID)

        #expect(result.id == SIGNATURE_ID)
        #expect(result.signature == nil)
        #expect(outsider.signedMessages.isEmpty)
        #expect(walletService.approveSignatureCallCount == 0)
    }
}
