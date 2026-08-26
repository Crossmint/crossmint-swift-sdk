import CrossmintCommonTypes
import DeviceSigner
import Foundation
import Logger

/// A Crossmint smart wallet on the Solana chain.
///
/// Obtain an instance via ``CrossmintWallets/getWallet(chain:recovery:options:)``
/// or ``CrossmintWallets/createWallet(chain:recovery:options:)``.
public final class SolanaWallet: Wallet, WalletOnChain, @unchecked Sendable {
    public typealias SpecificChain = SolanaChain

    public static func from(wallet: Wallet) throws(WalletError) -> SolanaWallet {
        guard let SolanaWallet = wallet as? SolanaWallet else {
            throw .walletInvalidType("Cannot create an Solana with the provided wallet")
        }
        return SolanaWallet
    }

    internal init(
        smartWalletService: SmartWalletService,
        signer: any Signer,
        baseModel: WalletApiModel,
        solanaChain: SolanaChain,
        onTransactionStart: (() -> Void)? = nil,
        deviceSignerKeyStorage: (any DeviceSignerKeyStorage)? = nil,
        deviceSignerUnsupported: Bool = false
    ) throws(WalletError) {
        var effectiveSigner = signer

        switch baseModel.config.recovery.type {
        case .apiKey:
            guard let apiKeyData = baseModel.config.recovery.toDomain as? ApiKeySignerData else {
                throw .walletGeneric("Recovery signer is not an ApiKeySignerData")
            }
            effectiveSigner = ApiKeySigner(adminSigner: apiKeyData)
        default:
            break
        }

        do {
            try super.init(
                smartWalletService: smartWalletService,
                signer: effectiveSigner,
                baseModel: baseModel,
                chain: solanaChain.chain,
                address: .solana(SolanaAddress(address: baseModel.address)),
                onTransactionStart: onTransactionStart,
                deviceSignerKeyStorage: deviceSignerKeyStorage,
                deviceSignerUnsupported: deviceSignerUnsupported
            )
        } catch {
            throw .walletInvalidType("The address \(baseModel.address) is not compatible with Solana")
        }
    }

    @available(
        *, deprecated, renamed: "sendTransaction(transaction:)",
        message: "Use the new sendTransaction method. This one will be removed."
    )
    public func sendTransaction(
        transaction: String
    ) async throws(TransactionError) -> Transaction {
        guard let transaction = try await super.sendTransaction(
            CreateSolanaTransactionRequest(transaction: transaction)
        ) else { throw .transactionGeneric("Unknown error") }

        return transaction
    }

    /// Submits a serialized Solana transaction and polls until it is confirmed on-chain.
    ///
    /// - Parameter transaction: A base64-encoded, serialized Solana transaction.
    ///
    /// ## Example
    /// ```swift
    /// let summary = try await solanaWallet.sendTransaction(transaction: base64EncodedTx)
    /// print("Signature:", summary.hash)
    /// ```
    public func sendTransaction(
        transaction: String
    ) async throws(TransactionError) -> TransactionSummary {
        Logger.smartWallet.info(LogEvents.solanaSendTransactionStart)

        guard let tx = try await super.sendTransaction(
            CreateSolanaTransactionRequest(transaction: transaction)
        ) else { throw .transactionGeneric("Unknown error") }

        Logger.smartWallet.info(LogEvents.solanaSendTransactionPrepared, attributes: [
            "transactionId": tx.id
        ])

        guard let completedTransaction = tx.toCompleted() else {
            throw .transactionGeneric("Unknown error")
        }

        Logger.smartWallet.info(LogEvents.solanaSendTransactionSuccess, attributes: [
            "transactionId": completedTransaction.id,
            "hash": completedTransaction.onChain.txId
        ])

        return completedTransaction.summary
    }
}
