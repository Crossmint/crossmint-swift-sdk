//
//  WalletPasskeyApprovalTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 30/09/26.
//

import Foundation
import Testing
import TestsUtils

@testable import Wallet

private let CREDENTIAL_ID = "v-Qxh--c2nOkUyBYJHRaXCwSOJw"
private let APPROVAL_BYTES_HEX = "0x" + String(repeating: "ab", count: 32)

@Suite("Passkey approval", .tags(.unit))
struct WalletPasskeyApprovalTests {
    private let walletService = MockSmartWalletService()
    private let passkey = MockPasskeySigner(credentialId: CREDENTIAL_ID)

    private func approve(
        on wallet: Wallet,
        pending: any TransactionApiModel,
        completed: any TransactionApiModel
    ) async throws {
        walletService.fetchTransactionResult = pending
        walletService.transactionAfterSigning = completed
        wallet.selectedSigner = passkey

        _ = try await wallet.approve(transactionId: "transaction-id")
    }

    @Test func signsTheStellarApprovalBytesAsTheChallenge() async throws {
        let wallet = try StellarWallet(
            smartWalletService: walletService,
            signer: MockSigner(),
            baseModel: try GetFromFile.getModelFrom(fileName: "WalletStellarPasskey", bundle: Bundle.module),
            stellarChain: .stellar
        )
        let pending: StellarTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "StellarPasskeyApprovalPending",
            bundle: Bundle.module
        )
        let completed: StellarTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "StellarTransactionSuccess",
            bundle: Bundle.module
        )

        try await approve(on: wallet, pending: pending, completed: completed)

        #expect(passkey.signLastMessage == APPROVAL_BYTES_HEX)
    }

    @Test func signsTheSolanaApprovalBytesAsTheChallenge() async throws {
        let wallet = try SolanaWallet(
            smartWalletService: walletService,
            signer: MockSigner(),
            baseModel: try GetFromFile.getModelFrom(fileName: "WalletSolanaEmail", bundle: Bundle.module),
            solanaChain: .solana
        )
        let pending: SolanaTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "SolanaPasskeyApprovalPending",
            bundle: Bundle.module
        )
        let completed: SolanaTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "RemoveSignerTransactionSuccess",
            bundle: Bundle.module
        )

        try await approve(on: wallet, pending: pending, completed: completed)

        #expect(passkey.signLastMessage == APPROVAL_BYTES_HEX)
    }

    @Test func signsTheEVMApprovalMessageUnchanged() async throws {
        let wallet = try EVMWallet(
            smartWalletService: walletService,
            signer: MockSigner(),
            baseModel: try GetFromFile.getModelFrom(fileName: "WalletEVMEmail", bundle: Bundle.module),
            evmChain: .baseSepolia
        )
        let pending: EVMTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "CreateTransactionAwaitingApproval",
            bundle: Bundle.module
        )
        let completed: EVMTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "GetTransactionResponse",
            bundle: Bundle.module
        )

        try await approve(on: wallet, pending: pending, completed: completed)

        #expect(passkey.signLastMessage == "0x387a634c711bc1465dbccaf83020bcb9b36a1859436b068ce015b2a20fb36a6e")
    }
}
