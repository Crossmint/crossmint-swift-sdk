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

private let ALICE = "email:alice@example.com"
private let PHONE = "phone:+14155552671"
private let EXTERNAL_WALLET_ADDRESS = "GbA2NZfpAnRVM2G2BG29qooqsYbdV5c2WVFymJ8MMir7"
private let EXTERNAL_WALLET = "external-wallet:\(EXTERNAL_WALLET_ADDRESS)"

@Suite("Wallet recovery method changes", .tags(.unit))
struct WalletRecoveryMethodChangesTests {
    private let walletService = MockSmartWalletService()

    private func makeWallet(
        fileName: String = "WalletSolanaRecoveryMethods",
        signerEmail: String = "alice@example.com"
    ) throws -> Wallet {
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(fileName: fileName, bundle: Bundle.module)
        let signer = MockSigner(email: signerEmail)
        if fileName.hasPrefix("WalletEVM") {
            return try EVMWallet(
                smartWalletService: walletService,
                signer: signer,
                baseModel: baseModel,
                evmChain: .polygon
            )
        }
        return try SolanaWallet(
            smartWalletService: walletService,
            signer: signer,
            baseModel: baseModel,
            solanaChain: .solana
        )
    }

    private func solanaTransaction(_ fileName: String) throws -> SolanaTransactionApiModel {
        try GetFromFile.getModelFrom(fileName: fileName, bundle: Bundle.module)
    }

    @Test func signsThePendingApprovalAndRecordsTheAddedMethod() async throws {
        let wallet = try makeWallet(fileName: "WalletSolanaEmail", signerEmail: "admin@example.com")
        walletService.addRecoveryMethodResult = try solanaTransaction("SolanaSignerRegistrationAwaitingApproval")
        walletService.fetchTransactionResult = try solanaTransaction("RemoveSignerTransactionSuccess")

        try await wallet.addRecoveryMethod(.phone("+14155552671"))

        #expect(walletService.signTransactionCallCount == 1)
        #expect(walletService.lastAddRecoveryMethodApprover == .email("solana.user@example.com"))
        #expect(wallet.recoveryMethods.map(\.locator) == ["email:solana.user@example.com", PHONE])
    }

    @Test func clearsTheSelectedRecoveryMethodWhenItIsRemoved() async throws {
        let wallet = try makeWallet()
        walletService.removeRecoveryMethodResult = try solanaTransaction("RemoveSignerTransactionSuccess")
        try await wallet.useRecoveryMethod(.phone("+14155552671"))
        try await wallet.removeRecoveryMethod(locator: .phone("+14155552671"))

        try await wallet.removeRecoveryMethod(locator: .externalWallet(address: EXTERNAL_WALLET_ADDRESS))

        #expect(walletService.lastRemoveRecoveryMethodApprover == .email("alice@example.com"))
    }

    @Test(arguments: [
        ("RemoveSignerTransactionSuccess", [ALICE, EXTERNAL_WALLET]),
        ("RecoveryMethodTransactionFailed", [ALICE, PHONE, EXTERNAL_WALLET])
    ])
    func updatesTheRecoveryMethodsOnlyWhenTheRemovalSucceeds(fixture: String, expected: [String]) async throws {
        let wallet = try makeWallet()
        walletService.removeRecoveryMethodResult = try solanaTransaction(fixture)

        _ = try? await wallet.removeRecoveryMethod(locator: .phone("+14155552671"))

        #expect(wallet.recoveryMethods.map(\.locator) == expected)
    }

    @Test(arguments: [
        ("WalletEVMEmail", SignerConfig.email("backup@example.com"), "RECOVERY_NOT_SUPPORTED_ON_CHAIN"),
        ("WalletSolanaEmail", SignerConfig.device, "WALLET_ERROR")
    ])
    func refusesAnAdditionBeforeCallingCrossmint(fileName: String, method: SignerConfig, code: String) async throws {
        let wallet = try makeWallet(fileName: fileName)

        let error = await #expect(throws: WalletError.self) {
            try await wallet.addRecoveryMethod(method)
        }

        #expect(error?.code == code)
        #expect(walletService.addRecoveryMethodCallCount == 0)
    }

    @Test func refusesARemovalOnAnEVMWalletBeforeCallingCrossmint() async throws {
        let wallet = try makeWallet(fileName: "WalletEVMEmail")

        let error = await #expect(throws: WalletError.self) {
            try await wallet.removeRecoveryMethod(locator: .email("backup@example.com"))
        }

        #expect(error?.code == "RECOVERY_NOT_SUPPORTED_ON_CHAIN")
        #expect(walletService.removeRecoveryMethodCallCount == 0)
    }
}
