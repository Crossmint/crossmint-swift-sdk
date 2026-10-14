//
//  WalletApproveTransactionTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 01/10/26.
//

import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils

@testable import Wallet

@Suite("Wallet approve", .tags(.unit))
struct WalletApproveTransactionTests {
    @Test func leavesAnApiKeyApprovalToTheServer() async throws {
        let walletService = MockSmartWalletService()
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(fileName: "WalletEVMApiKey", bundle: Bundle.module)
        let wallet = try EVMWallet(
            smartWalletService: walletService,
            signer: ApiKeySigner(adminSigner: ApiKeySignerData(address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")),
            baseModel: baseModel,
            evmChain: .baseSepolia
        )
        let awaiting: EVMTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "TransactionAwaitingApiKeyApproval",
            bundle: Bundle.module
        )
        let completed: EVMTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "GetTransactionResponse",
            bundle: Bundle.module
        )
        walletService.fetchTransactionResults = [awaiting, completed]

        let transaction = try await wallet.approve(transactionId: "da17e29a-c0b3-4506-9e87-f5d343ea0d2e")

        #expect(transaction.status == .success)
        #expect(walletService.signTransactionCallCount == 0)
    }

    @Test(arguments: [
        ("WalletStellarRecoveryMethods", "0x04aced3cd44a08e109d70a88275aa08d67a1cd44f5835004fec5a3a52e32c67e"),
        ("WalletSolanaEmail", "0x04aced3cd44a08e109d70a88275aa08d67a1cd44f5835004fec5a3a52e32c67e"),
        ("WalletEVMEmail", "BKztPNRKCOEJ1wqIJ1qgjWehzUT1g1AE/sWjpS4yxn4=")
    ])
    func signsThePasskeyChallengeThatTheWalletChainExpects(fixture: String, challenge: String) async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeWallet(fixture: fixture, walletService: walletService)
        let pending: StellarTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "CreateStellarTransactionResponse",
            bundle: Bundle.module
        )
        let completed: SolanaTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "RemoveSignerTransactionSuccess",
            bundle: Bundle.module
        )
        walletService.fetchTransactionResults = [pending]
        walletService.fetchTransactionResult = completed
        let passkey = MockSigner(email: "user@example.com", signerType: .passkey)
        wallet.selectedSigner = passkey

        _ = try await wallet.approve(transactionId: pending.id)

        #expect(passkey.signLastMessage == challenge)
    }
}
