import CrossmintCommonTypes
import Foundation

public struct EVMTransactionApiModel: TransactionApiModel {

    public struct OnChainData: Decodable {
        public let userOperation: UserOperation
        public let userOperationHash: String
        public let explorerLink: String?
        public let txId: String?

        var toDomain: Transaction.OnChainData {
            Transaction.OnChainData(
                userOperation: userOperation.toDomain,
                userOperationHash: userOperationHash,
                explorerLink: URL(string: explorerLink ?? ""),
                txId: txId
            )
        }
    }

    public struct UserOperation: Decodable {
        public let paymaster: String
        public let paymasterVerificationGasLimit: String
        public let preVerificationGas: String
        public let nonce: String
        public let paymasterPostOpGasLimit: String
        public let factoryData: String?
        public let factory: String?
        public let signature: String
        public let callGasLimit: String
        public let paymasterData: String
        public let verificationGasLimit: String
        public let maxFeePerGas: String
        public let sender: String
        public let callData: String
        public let maxPriorityFeePerGas: String

        var toDomain: Transaction.UserOperation {
            Transaction.UserOperation(
                paymaster: paymaster,
                paymasterVerificationGasLimit: paymasterVerificationGasLimit,
                preVerificationGas: preVerificationGas,
                nonce: nonce,
                paymasterPostOpGasLimit: paymasterPostOpGasLimit,
                factoryData: factoryData,
                factory: factory,
                signature: signature,
                callGasLimit: callGasLimit,
                paymasterData: paymasterData,
                verificationGasLimit: verificationGasLimit,
                maxFeePerGas: maxFeePerGas,
                sender: sender,
                callData: callData,
                maxPriorityFeePerGas: maxPriorityFeePerGas
            )
        }
    }

    public struct Params: Decodable, Sendable {
        public let calls: [Call]
        public let chain: Chain
        public let signer: SignerApiModel

        enum CodingKeys: CodingKey {
            case calls
            case chain
            case signer
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.chain = Chain(try container.decode(String.self, forKey: .chain))
            self.signer = try container.decode(SignerApiModel.self, forKey: .signer)
            self.calls = try container.decode([Call].self, forKey: .calls)
        }

        var toDomain: Transaction.Params {
            Transaction.Params(
                calls: calls.map { $0.toDomain },
                chain: chain,
                signer: signer.locator
            )
        }
    }

    public struct Call: Decodable, Sendable {
        public let to: String
        public let value: String
        public let data: String

        var toDomain: Transaction.Call {
            Transaction.Call(to: to, value: value, data: data)
        }
    }

    public let id: String
    public let status: TransactionStatusApiModel
    public let onChain: OnChainData
    public let params: Params
    public let walletType: WalletType
    public let createdAt: Date
    public let approvals: Approvals
    public let error: TransactionErrorApiModel?

    public func toDomain(withService service: SmartWalletService) -> Transaction? {
        Transaction(
            smartWalletService: service,
            id: id,
            status: status.toDomain,
            onChain: onChain.toDomain,
            params: params.toDomain,
            walletType: walletType,
            createdAt: createdAt,
            approvals: approvals.toDomain,
            error: error?.toDomain
        )
    }
}
