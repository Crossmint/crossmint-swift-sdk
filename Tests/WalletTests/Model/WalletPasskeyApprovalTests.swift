//
//  WalletPasskeyApprovalTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 30/09/26.
//

import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils

@testable import Wallet

private let APPROVAL_MESSAGE = "BKztPNRKCOEJ1wqIJ1qgjWehzUT1g1AE/sWjpS4yxn4="
private let APPROVAL_BYTES_HEX = "0x04aced3cd44a08e109d70a88275aa08d67a1cd44f5835004fec5a3a52e32c67e"

@Suite("Passkey approval", .tags(.unit))
struct WalletPasskeyApprovalTests {
    private let walletService = MockSmartWalletService()

    private func makeWallet(on chainType: ChainType) throws -> Wallet {
        switch chainType {
        case .stellar:
            try StellarWallet(
                smartWalletService: walletService,
                signer: nil,
                baseModel: try GetFromFile.getModelFrom(fileName: "WalletStellarRecoveryMethods", bundle: .module),
                stellarChain: .stellar
            )
        case .solana:
            try SolanaWallet(
                smartWalletService: walletService,
                signer: nil,
                baseModel: try GetFromFile.getModelFrom(fileName: "WalletSolanaEmail", bundle: .module),
                solanaChain: .solana
            )
        default:
            try EVMWallet(
                smartWalletService: walletService,
                signer: nil,
                baseModel: try GetFromFile.getModelFrom(fileName: "WalletEVMEmail", bundle: .module),
                evmChain: .baseSepolia
            )
        }
    }

    @Test(arguments: [
        (ChainType.stellar, APPROVAL_BYTES_HEX),
        (ChainType.solana, APPROVAL_BYTES_HEX),
        (ChainType.evm, APPROVAL_MESSAGE)
    ])
    func signsTheChallengeThatTheWalletChainExpects(chainType: ChainType, challenge: String) async throws {
        let pending: StellarTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "CreateStellarTransactionResponse",
            bundle: .module
        )
        let completed: SolanaTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "RemoveSignerTransactionSuccess",
            bundle: .module
        )
        walletService.fetchTransactionResults = [pending]
        walletService.fetchTransactionResult = completed
        let wallet = try makeWallet(on: chainType)
        let passkey = MockSigner(email: "user@example.com", signerType: .passkey)
        wallet.selectedSigner = passkey

        _ = try await wallet.approve(transactionId: pending.id)

        #expect(passkey.signLastMessage == challenge)
    }
}
