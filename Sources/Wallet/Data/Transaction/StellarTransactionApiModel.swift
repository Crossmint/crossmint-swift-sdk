//
//  StellarTransactionApiModel.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 12/22/25.
//

import CrossmintCommonTypes
import Foundation
import Utils

public struct StellarTransactionApiModel: TransactionApiModel {
    public typealias StellarApprovalEntry = ApprovalEntry
    public typealias StellarSubmittedApprovalEntry = SubmittedApprovalEntry
    public typealias StellarApprovals = Approvals

    public struct StellarOnChainTransaction: Decodable {
        public let method: String
        public let tx: String
    }

    public struct OnChainData: Decodable {
        public let transaction: StellarOnChainTransaction
        public let txId: String?
        public let explorerLink: String?
        public let expiration: Int?
        public let ledger: Int?

        var toDomain: Transaction.OnChainData {
            Transaction.OnChainData(
                userOperation: nil,
                userOperationHash: nil,
                explorerLink: URL(string: explorerLink ?? ""),
                txId: txId,
                transaction: transaction.tx,
                lastValidBlockHeight: nil
            )
        }
    }

    public struct Params: Decodable, Sendable {
        public let transaction: AnyCodable
        public let signer: SignerApiModel?
        public let feeConfig: FeeConfig?

        var toDomain: Transaction.Params {
            Transaction.Params(
                calls: nil,
                chain: nil,
                signer: signer?.locator ?? "",
                transaction: nil,
                feeConfig: feeConfig?.toDomain
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

    public func toDomain() -> Transaction {
        Transaction(
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
