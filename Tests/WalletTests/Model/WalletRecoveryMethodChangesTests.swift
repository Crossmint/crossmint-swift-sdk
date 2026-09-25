//
//  WalletRecoveryMethodChangesTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 25/09/26.
//

import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils

@testable import Wallet

@Suite("Wallet recovery method changes", .tags(.unit))
struct WalletRecoveryMethodChangesTests {
    private func makeSolanaWallet(
        fileName: String,
        signer: MockSigner
    ) throws -> (SolanaWallet, MockSmartWalletService) {
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(fileName: fileName, bundle: Bundle.module)
        let walletService = MockSmartWalletService()
        walletService.getWalletResult = baseModel
        let wallet = try SolanaWallet(
            smartWalletService: walletService,
            signer: signer,
            baseModel: baseModel,
            solanaChain: .solana
        )
        return (wallet, walletService)
    }

    private func solanaTransaction(_ fileName: String) throws -> SolanaTransactionApiModel {
        try GetFromFile.getModelFrom(fileName: fileName, bundle: Bundle.module)
    }

    private func recoveryLocators(_ wallet: Wallet) -> [String] {
        wallet.recoveryMethods.map(\.locator)
    }

    @Test func signsThePendingApprovalAndRecordsTheAddedMethod() async throws {
        let (wallet, walletService) = try makeSolanaWallet(
            fileName: "WalletSolanaEmail",
            signer: MockSigner(email: "admin@example.com")
        )
        walletService.addRecoveryMethodResult = try solanaTransaction("SolanaSignerRegistrationAwaitingApproval")
        walletService.fetchTransactionResult = try solanaTransaction("RemoveSignerTransactionSuccess")

        let transaction = try await wallet.addRecoveryMethod(.phone("+14155552671"))

        #expect(transaction.status == .success)
        #expect(walletService.signTransactionCallCount == 1)
        #expect(walletService.lastSignTransactionRequest?.transactionId == "registration-tx-1")
        #expect(walletService.lastAddRecoveryMethodApprover == .email("solana.user@example.com"))
        #expect(recoveryLocators(wallet) == ["email:solana.user@example.com", "phone:+14155552671"])
    }

    @Test func clearsTheSelectedRecoveryMethodWhenItIsRemoved() async throws {
        let (wallet, walletService) = try makeSolanaWallet(
            fileName: "WalletSolanaRecoveryMethods",
            signer: MockSigner(email: "alice@example.com")
        )
        walletService.removeRecoveryMethodResult = try solanaTransaction("RemoveSignerTransactionSuccess")
        try await wallet.useRecoveryMethod(.phone("+14155552671"))
        _ = try await wallet.removeRecoveryMethod(locator: .phone("+14155552671"))

        _ = try await wallet.removeRecoveryMethod(
            locator: .externalWallet(address: "GbA2NZfpAnRVM2G2BG29qooqsYbdV5c2WVFymJ8MMir7")
        )

        #expect(walletService.lastRemoveRecoveryMethodApprover == .email("alice@example.com"))
    }

    @Test func forgetsTheRemovedMethod() async throws {
        let (wallet, walletService) = try makeSolanaWallet(
            fileName: "WalletSolanaRecoveryMethods",
            signer: MockSigner(email: "alice@example.com")
        )
        walletService.removeRecoveryMethodResult = try solanaTransaction("RemoveSignerTransactionSuccess")

        _ = try await wallet.removeRecoveryMethod(locator: .phone("+14155552671"))

        #expect(walletService.lastRemoveRecoveryMethodLocator == .phone("+14155552671"))
        #expect(recoveryLocators(wallet) == [
            "email:alice@example.com",
            "external-wallet:GbA2NZfpAnRVM2G2BG29qooqsYbdV5c2WVFymJ8MMir7"
        ])
    }

    @Test func keepsTheRecoveryMethodsWhenTheTransactionFails() async throws {
        let (wallet, walletService) = try makeSolanaWallet(
            fileName: "WalletSolanaRecoveryMethods",
            signer: MockSigner(email: "alice@example.com")
        )
        walletService.removeRecoveryMethodResult = try solanaTransaction("RecoveryMethodTransactionFailed")
        let before = recoveryLocators(wallet)

        await #expect(throws: WalletError.self) {
            try await wallet.removeRecoveryMethod(locator: .phone("+14155552671"))
        }

        #expect(recoveryLocators(wallet) == before)
    }

    @Test func rejectsASignerTypeThatCannotRecoverTheWallet() async throws {
        let (wallet, walletService) = try makeSolanaWallet(
            fileName: "WalletSolanaEmail",
            signer: MockSigner(email: "admin@example.com")
        )

        await #expect(throws: WalletError.self) {
            try await wallet.addRecoveryMethod(.device)
        }

        #expect(walletService.addRecoveryMethodCallCount == 0)
    }

    @Test(arguments: [true, false])
    func rejectsAnEVMWalletBeforeCallingCrossmint(adding: Bool) async throws {
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(fileName: "WalletEVMEmail", bundle: Bundle.module)
        let walletService = MockSmartWalletService()
        let wallet = try EVMWallet(
            smartWalletService: walletService,
            signer: MockSigner(),
            baseModel: baseModel,
            evmChain: .polygon
        )

        let error = await #expect(throws: WalletError.self) {
            if adding {
                try await wallet.addRecoveryMethod(.email("backup@example.com"))
            } else {
                try await wallet.removeRecoveryMethod(locator: .email("backup@example.com"))
            }
        }

        #expect(error?.code == "RECOVERY_NOT_SUPPORTED_ON_CHAIN")
        #expect(walletService.addRecoveryMethodCallCount + walletService.removeRecoveryMethodCallCount == 0)
    }
}
