import CrossmintCommonTypes
import Foundation

internal struct TransactionCompleted: Sendable {
    internal struct OnChainData: Sendable {
        internal let userOperation: Transaction.UserOperation?
        internal let userOperationHash: String?
        internal let explorerLink: URL
        internal let txId: String
        internal let transaction: String?
        internal let lastValidBlockHeight: Int?

        internal init(
            userOperation: Transaction.UserOperation? = nil,
            userOperationHash: String? = nil,
            explorerLink: URL,
            txId: String,
            transaction: String? = nil,
            lastValidBlockHeight: Int? = nil
        ) {
            self.userOperation = userOperation
            self.userOperationHash = userOperationHash
            self.explorerLink = explorerLink
            self.txId = txId
            self.transaction = transaction
            self.lastValidBlockHeight = lastValidBlockHeight
        }
    }

    internal let id: String
    internal let status: Transaction.Status
    internal let onChain: OnChainData
    internal let params: Transaction.Params
    internal let walletType: WalletType
    internal let createdAt: Date
    internal let approvals: Transaction.Approvals?

    internal init(
        id: String,
        status: Transaction.Status,
        onChain: OnChainData,
        params: Transaction.Params,
        walletType: WalletType,
        createdAt: Date,
        approvals: Transaction.Approvals? = nil
    ) {
        self.id = id
        self.status = status
        self.onChain = onChain
        self.params = params
        self.walletType = walletType
        self.createdAt = createdAt
        self.approvals = approvals
    }

    var summary: TransactionSummary {
        TransactionSummary(
            hash: id,
            transactionID: onChain.txId,
            explorerLink: onChain.explorerLink
        )
    }
}
