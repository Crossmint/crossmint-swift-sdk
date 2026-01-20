//
//  StellarTransactionApiModel.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 12/22/25.
//

import CrossmintCommonTypes
import Foundation

public struct StellarTransactionApiModel: TransactionApiModel {
    public struct StellarApprovalEntry: Decodable {
        let signer: SignerApiModel
        let message: String
    }

    public struct StellarSubmittedApprovalEntry: Decodable {
        let signature: String
        let submittedAt: Date
        let signer: SignerApiModel
        let message: String
    }

    public struct StellarApprovals: Decodable {
        let required: Int?
        let pending: [StellarApprovalEntry]
        let submitted: [StellarSubmittedApprovalEntry]

        var toDomain: Transaction.Approvals {
            Transaction.Approvals(
                pending: pending.map { Transaction.Approvals.Pending(signer: $0.signer.locator, message: $0.message) },
                submitted: submitted.map {
                    Transaction.Approvals.Submitted(
                        signature: $0.signature,
                        submittedAt: $0.submittedAt,
                        signer: $0.signer.locator,
                        message: $0.message
                    )
                }
            )
        }
    }

    public struct OnChainData: Decodable {
        public let transaction: String
        public let txId: String?
        public let explorerLink: String?

        var toDomain: Transaction.OnChainData {
            Transaction.OnChainData(
                userOperation: nil,
                userOperationHash: nil,
                explorerLink: URL(string: explorerLink ?? ""),
                txId: txId,
                transaction: transaction,
                lastValidBlockHeight: nil
            )
        }
    }

    public struct Params: Decodable, Sendable {
        public let transaction: String
        public let signer: SignerApiModel
        public let feeConfig: FeeConfig

        var toDomain: Transaction.Params {
            Transaction.Params(
                calls: nil,
                chain: nil,
                signer: signer.locator,
                transaction: transaction,
                feeConfig: feeConfig.toDomain
            )
        }
    }

    public struct FeeConfig: Decodable, Sendable {
        public let feePayer: String
        public let amount: String

        var toDomain: Transaction.FeeConfig {
            Transaction.FeeConfig(feePayer: feePayer, amount: amount)
        }
    }

    public struct SendParams: Decodable {
        public struct Params: Decodable {
            public let amount: String
            public let recipient: String
            public let recipientAddress: String
        }

        public let token: String
        public let params: Params
    }

    public let id: String
    public let status: TransactionStatusApiModel
    public let onChain: OnChainData
    public let params: Params
    public let chainType: String?
    public let walletType: WalletType
    public let createdAt: Date
    public let approvals: StellarApprovals?
    public let error: TransactionErrorApiModel?
    public let sendParams: SendParams?

    public func toDomain(withService service: SmartWalletService) -> Transaction? {
        Transaction(
            smartWalletService: service,
            id: id,
            status: status.toDomain,
            onChain: onChain.toDomain,
            params: params.toDomain,
            walletType: walletType,
            createdAt: createdAt,
            approvals: approvals?.toDomain,
            error: error?.toDomain
        )
    }
}
