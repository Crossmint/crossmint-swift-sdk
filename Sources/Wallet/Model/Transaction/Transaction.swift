import CrossmintCommonTypes
import Foundation
import Utils

public struct Transaction: Sendable, CustomStringConvertible {
    let smartWalletService: SmartWalletService

    public enum Status: Sendable {
        case pending
        case success
        case failed
        case awaitingApproval
    }

    public struct OnChainData: Sendable {
        public let userOperation: UserOperation?
        public let userOperationHash: String?
        public let explorerLink: URL?
        public let txId: String?
        public let transaction: String?
        public let lastValidBlockHeight: Int?

        public init(
            userOperation: UserOperation? = nil,
            userOperationHash: String? = nil,
            explorerLink: URL? = nil,
            txId: String? = nil,
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

    public struct UserOperation: Sendable {
        public let paymaster: String?
        public let paymasterVerificationGasLimit: String?
        public let preVerificationGas: String
        public let nonce: String
        public let paymasterPostOpGasLimit: String?
        public let factoryData: String?
        public let factory: String?
        public let signature: String
        public let callGasLimit: String
        public let paymasterData: String?
        public let verificationGasLimit: String
        public let maxFeePerGas: String
        public let sender: String
        public let callData: String
        public let maxPriorityFeePerGas: String

        public var maxFeePerGasDecimal: Decimal? {
            guard let value = Decimal(hexString: maxFeePerGas) else { return nil }
            return value
        }

        public var maxPriorityFeePerGasDecimal: Decimal? {
            guard let value = Decimal(hexString: maxPriorityFeePerGas) else { return nil }
            return value
        }
    }

    public struct Params: Sendable {
        public let calls: [Call]?
        public let chain: Chain?
        public let signer: String
        public let transaction: String?
        public let feeConfig: FeeConfig?

        public init(
            calls: [Call]? = nil,
            chain: Chain? = nil,
            signer: String,
            transaction: String? = nil,
            feeConfig: FeeConfig? = nil
        ) {
            self.calls = calls
            self.chain = chain
            self.signer = signer
            self.transaction = transaction
            self.feeConfig = feeConfig
        }
    }

    public struct Call: Sendable {
        public let to: String
        public let value: String
        public let data: String
    }

    public struct FeeConfig: Sendable {
        public let feePayer: String
        public let amount: String

        public init(feePayer: String, amount: String) {
            self.feePayer = feePayer
            self.amount = amount
        }
    }

    public struct Approvals: Sendable {
        public struct Pending: Sendable {
            let signer: String
            let message: String
        }

        public struct Submitted: Sendable {
            let signature: String
            let submittedAt: Date
            let signer: String
            let message: String
        }

        let pending: [Approvals.Pending]
        let submitted: [Approvals.Submitted]
    }

    public struct Error: Sendable {
        public let reason: String
        public let message: String
        public let revert: Revert?

        public struct Revert: Sendable {
            public let type: String
            public let reason: String
            public let simulationLink: URL
        }
    }

    public let id: String
    public let status: Status
    public let onChain: OnChainData
    public let params: Params
    public let walletType: WalletType
    public let createdAt: Date
    public let approvals: Approvals?
    public let error: Error?

    public init(
        smartWalletService: SmartWalletService,
        id: String,
        status: Status,
        onChain: OnChainData,
        params: Params,
        walletType: WalletType,
        createdAt: Date,
        approvals: Approvals?,
        error: Error?
    ) {
        self.smartWalletService = smartWalletService
        self.id = id
        self.status = status
        self.onChain = onChain
        self.params = params
        self.walletType = walletType
        self.createdAt = createdAt
        self.approvals = approvals
        self.error = error
    }

    public var description: String {
        // swiftlint:disable:next line_length
         "id: \(id), status: \(status), onChain: \(onChain), params: \(params), walletType: \(walletType), createdAt: \(createdAt), approvals: \(String(describing: approvals)), error: \(String(describing: error))"
    }

    internal func toCompleted() -> TransactionCompleted? {
        // Only convert if transaction is successful and has required fields
        guard status == .success,
              let txId = onChain.txId,
              let explorerLink = onChain.explorerLink else {
            return nil
        }

        let completedOnChainData = TransactionCompleted.OnChainData(
            userOperation: onChain.userOperation,
            userOperationHash: onChain.userOperationHash,
            explorerLink: explorerLink,
            txId: txId,
            transaction: onChain.transaction,
            lastValidBlockHeight: onChain.lastValidBlockHeight
        )

        return TransactionCompleted(
            id: id,
            status: status,
            onChain: completedOnChainData,
            params: params,
            walletType: walletType,
            createdAt: createdAt,
            approvals: approvals
        )
    }
}
