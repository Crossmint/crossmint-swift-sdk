//
//  WalletQuorumChainTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 29/10/26.
//

import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils

@testable import Wallet

private let QUORUM = SignerLocator.quorum(id: "9f2c6a1e-4b7d-4c3a-9e51-2d8f0b6c7a14")

@Suite("Wallet quorum on EVM and Solana", .tags(.unit))
struct WalletQuorumChainTests {
    private func makeEVMWallet(walletService: MockSmartWalletService) throws -> EVMWallet {
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(fileName: "WalletEVMQuorum", bundle: Bundle.module)
        walletService.getWalletResult = baseModel
        return try EVMWallet(
            smartWalletService: walletService,
            signer: nil,
            baseModel: baseModel,
            evmChain: .baseSepolia
        )
    }

    private func makeSolanaWallet(walletService: MockSmartWalletService) throws -> SolanaWallet {
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletSolanaQuorum",
            bundle: Bundle.module
        )
        walletService.getWalletResult = baseModel
        return try SolanaWallet(
            smartWalletService: walletService,
            signer: nil,
            baseModel: baseModel,
            solanaChain: .solana
        )
    }

    private func sentEVMSigner(_ walletService: MockSmartWalletService) -> String? {
        (walletService.createTransactionLastRequest?.request as? CreateEVMTransactionRequest)?.signer
    }

    @Test func createsAnEVMTransactionForTheQuorumWhenTheSignerIsOnlyAMember() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeEVMWallet(walletService: walletService)
        walletService.createTransactionResult = try GetFromFile.getModelFrom(
            fileName: "CreateTransactionAwaitingApproval",
            bundle: Bundle.module
        ) as EVMTransactionApiModel
        try await wallet.useSigner(.phone("+14155552671"))

        let summary = try await wallet.sendTransaction(
            to: "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
            value: nil,
            data: nil
        )

        #expect(sentEVMSigner(walletService) == QUORUM.value)
        #expect(summary.hash == nil)
        #expect(walletService.signTransactionCallCount == 0)
    }

    @Test func returnsTheEVMSignerAdditionThatTheQuorumMustApprove() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeEVMWallet(walletService: walletService)
        let member = MockSigner(email: "bob@example.com")
        wallet.selectedSigner = member
        walletService.addSignerResult = AddDelegatedSignerResponse(
            chains: nil,
            transaction: RegistrationTransaction(id: "da17e29a-c0b3-4506-9e87-f5d343ea0d2e")
        )
        walletService.fetchTransactionResult = try GetFromFile.getModelFrom(
            fileName: "CreateTransactionAwaitingApproval",
            bundle: Bundle.module
        ) as EVMTransactionApiModel

        let pending = try await wallet.addSigner(.email("dave@example.com"), deployImmediately: true)

        #expect(pending?.id == "da17e29a-c0b3-4506-9e87-f5d343ea0d2e")
        #expect(member.signedMessages.isEmpty)
        #expect(walletService.lastAddSignerApprovingMembers == nil)
    }

    @Test func rejectsAnEVMSignerAdditionThatAQuorumWouldApproveLater() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeEVMWallet(walletService: walletService)
        wallet.selectedSigner = MockSigner(email: "bob@example.com")

        await #expect(throws: WalletError.self) {
            try await wallet.addSigner(.email("dave@example.com"), deployImmediately: false)
        }
        #expect(walletService.addSignerCallCount == 0)
    }

    @Test func rejectsASolanaTransferForAQuorumBeforeItIsCreated() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeSolanaWallet(walletService: walletService)
        try await wallet.useSigner(.phone("+14155552671"))

        await #expect {
            _ = try await wallet.send("7ZN9rAofFVVP1WKqfKozsVWQYcDj2u9juYyRkrKUVR8Y", "solana:usdc", 1)
        } throws: { error in
            guard case .quorumUnsupported(.solana) = error as? TransactionError else { return false }
            return true
        }
        #expect(walletService.transferTokenCallCount == 0)
    }

    @Test func rejectsASolanaTransferThatNamesAQuorum() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeSolanaWallet(walletService: walletService)
        try await wallet.useSigner(.phone("+14155552671"))

        await #expect {
            _ = try await wallet.send(
                "7ZN9rAofFVVP1WKqfKozsVWQYcDj2u9juYyRkrKUVR8Y",
                "solana:usdc",
                1,
                signer: QUORUM
            )
        } throws: { error in
            guard case .quorumUnsupported(.solana) = error as? TransactionError else { return false }
            return true
        }
        #expect(walletService.transferTokenCallCount == 0)
    }

    private func sentSolanaRequest(_ walletService: MockSmartWalletService) -> CreateSolanaTransactionRequest? {
        walletService.createTransactionLastRequest?.request as? CreateSolanaTransactionRequest
    }

    private func solanaTransaction(_ fileName: String) throws -> SolanaTransactionApiModel {
        try GetFromFile.getModelFrom(fileName: fileName, bundle: Bundle.module)
    }

    @Test func namesTheActiveMemberFirstWhenAQuorumSendsASolanaTransaction() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeSolanaWallet(walletService: walletService)
        walletService.createTransactionResult = try solanaTransaction("CreateSolanaTransactionResponse")
        try await wallet.useSigner(.phone("+14155552671"))

        let summary = try await wallet.sendTransaction(transaction: "AAAA", prepareOnly: false)

        let request = try #require(sentSolanaRequest(walletService))
        #expect(request.signer == QUORUM.value)
        #expect(request.approvingMembers == ["phone:+14155552671", "email:alice@example.com"])
        #expect(summary.hash == nil)
        #expect(walletService.signTransactionCallCount == 0)
    }

    @Test func sendsTheApprovingMembersThatTheCallerNamesForASolanaTransaction() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeSolanaWallet(walletService: walletService)
        walletService.createTransactionResult = try solanaTransaction("CreateSolanaTransactionResponse")
        try await wallet.useSigner(.phone("+14155552671"))

        _ = try await wallet.sendTransaction(
            transaction: "AAAA",
            signer: QUORUM,
            approvingMembers: [.email("bob@example.com"), .email("alice@example.com")]
        )

        let approvingMembers = sentSolanaRequest(walletService)?.approvingMembers
        #expect(approvingMembers == ["email:bob@example.com", "email:alice@example.com"])
    }

    @Test func namesTheSelectedMemberFirstWhenAQuorumApprovesASolanaSignerRemoval() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeSolanaWallet(walletService: walletService)
        walletService.removeSignerResult = try solanaTransaction("CreateSolanaTransactionResponse")
        wallet.selectedSigner = MockSigner(email: "bob@example.com")

        _ = try await wallet.removeSigner(locator: .email("dave@example.com"))

        #expect(walletService.removeSignerLastApprover == QUORUM)
        let approvingMembers = walletService.removeSignerLastApprovingMembers
        #expect(approvingMembers == [.email("bob@example.com"), .email("alice@example.com")])
    }

    @Test func reportsACancelledSolanaQuorumTransactionAndItsDeadline() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeSolanaWallet(walletService: walletService)
        walletService.fetchTransactionResult = try solanaTransaction("SolanaQuorumTransactionCancelled")

        let transaction = try await wallet.getTransaction(id: "5b1d3e0c-7a42-4c8e-9f16-2e7d8a9b0c31")

        #expect(transaction.status == .cancelled)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        #expect(transaction.validUntil == formatter.date(from: "2026-11-19T14:29:34.133Z"))
    }
}
