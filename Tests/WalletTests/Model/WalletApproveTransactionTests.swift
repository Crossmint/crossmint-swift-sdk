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
}
