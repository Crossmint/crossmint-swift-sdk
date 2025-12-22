//
//  StellarWallet.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 12/22/25.
//

import CrossmintCommonTypes
import Foundation
import Logger

public final class StellarWallet: Wallet, WalletOnChain, @unchecked Sendable {
    public typealias SpecificChain = StellarChain

    public static func from(wallet: Wallet) throws(WalletError) -> StellarWallet {
        guard let stellarWallet = wallet as? StellarWallet else {
            throw .walletInvalidType("Cannot create a Stellar wallet with the provided wallet")
        }
        return stellarWallet
    }

    internal init(
        smartWalletService: SmartWalletService,
        signer: any Signer,
        baseModel: WalletApiModel,
        stellarChain: StellarChain,
        onTransactionStart: (() -> Void)? = nil
    ) throws(WalletError) {
        var effectiveSigner = signer

        // Switch to API key signer if wallet uses API key admin
        switch baseModel.config.adminSigner.type {
        case .apiKey:
            effectiveSigner = StellarApiKeySigner()
        default:
            break
        }

        do {
            try super.init(
                smartWalletService: smartWalletService,
                signer: effectiveSigner,
                baseModel: baseModel,
                chain: stellarChain.chain,
                address: .stellar(StellarAddress(address: baseModel.address)),
                onTransactionStart: onTransactionStart
            )
        } catch {
            throw .walletInvalidType("The address \(baseModel.address) is not compatible with Stellar")
        }
    }

    // Primary transaction method - serialized transaction
    public func sendTransaction(
        transaction: String
    ) async throws(TransactionError) -> TransactionSummary {
        Logger.smartWallet.info(LogEvents.stellarSendTransactionStart)

        guard let tx = try await super.sendTransaction(
            CreateStellarTransactionRequest(transaction: transaction)
        ) else {
            throw .transactionGeneric("Unknown error")
        }

        Logger.smartWallet.info(LogEvents.stellarSendTransactionPrepared, attributes: [
            "transactionId": tx.id
        ])

        guard let completedTransaction = tx.toCompleted() else {
            throw .transactionGeneric("Unknown error")
        }

        Logger.smartWallet.info(LogEvents.stellarSendTransactionSuccess, attributes: [
            "transactionId": completedTransaction.id,
            "hash": completedTransaction.onChain.txId
        ])

        return completedTransaction.summary
    }
}
