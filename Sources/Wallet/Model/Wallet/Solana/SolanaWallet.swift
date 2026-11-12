import CrossmintCommonTypes
import DeviceSigner
import Foundation
import Logger

/// A Crossmint smart wallet on the Solana chain.
///
/// Obtain an instance via ``CrossmintWallets/getWallet(chain:options:)``
/// or ``CrossmintWallets/createWallet(chain:recoveryMethods:options:)``.
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
        signer: (any Signer)?,
        baseModel: WalletApiModel,
        solanaChain: SolanaChain,
        onTransactionStart: (() -> Void)? = nil,
        deviceSignerKeyStorage: (any DeviceSignerKeyStorage)? = nil,
        deviceSignerUnsupported: Bool = false
    ) throws(WalletError) {
        var effectiveSigner = signer

        switch baseModel.config.adminSigner.type {
        case .apiKey:
            guard let apiKeyData = baseModel.config.adminSigner.toDomain as? ApiKeySignerData else {
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
            CreateSolanaTransactionRequest(transaction: transaction, signer: try await transactionSignerLocator())
        ) else { throw .transactionGeneric("Unknown error") }

        return transaction
    }

    /// Submits a serialized Solana transaction and polls until it is confirmed on-chain.
    ///
    /// - Parameters:
    ///   - transaction: A base64-encoded, serialized Solana transaction.
    ///   - signer: The signer that sends the transaction. Use it to name the quorum to act for
    ///     when the active signer is a member of more than one quorum.
    ///   - approvingMembers: The quorum members that approve, when a quorum sends the transaction.
    ///     Name exactly as many members as the threshold. When you omit it, the SDK names the active member first,
    ///     then the other members in the order of the quorum.
    ///   - prepareOnly: Pass `true` to create the transaction without approving it.
    ///     Then approve it with ``Wallet/approve(transactionId:)``. The summary then has only the transaction ID.
    ///
    /// When a quorum sends the transaction, the SDK creates it without approving it, as with `prepareOnly`.
    /// Each designated member then approves it with ``Wallet/approve(transactionId:)``.
    ///
    /// ## Example
    /// ```swift
    /// let summary = try await solanaWallet.sendTransaction(transaction: base64EncodedTx)
    /// print("Signature:", summary.hash ?? "")
    /// ```
    public func sendTransaction(
        transaction: String,
        signer: SignerLocator? = nil,
        approvingMembers: [SignerLocator]? = nil,
        prepareOnly: Bool = false
    ) async throws(TransactionError) -> TransactionSummary {
        Logger.smartWallet.info(LogEvents.solanaSendTransactionStart)

        let signerLocator = try await transactionSignerLocator(explicit: signer)
        let request = CreateSolanaTransactionRequest(
            transaction: transaction,
            signer: signerLocator,
            approvingMembers: await transactionApprovingMembers(signer: signerLocator, explicit: approvingMembers)
        )
        guard let tx = try await super.sendTransaction(
            request,
            prepareOnly: prepareOnly || isQuorum(signerLocator)
        ) else { throw .transactionGeneric("Unknown error") }
        if let pending = tx.pendingSummary { return pending }

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
