import Foundation
import CrossmintCommonTypes
import Utils

public struct TypedDataSignatureResponse: SignatureApiModel {
    public let id: String
    public let type: String
    public let chainType: String?
    public let walletType: String?
    public let status: String
    public let params: TypedDataParams
    public let approvals: Approvals
    public let createdAt: Date

    public struct TypedDataParams: Decodable {
        public let typedData: TypedData
        public let chain: String
        public let signer: SignerApiModel
        public let isSmartWalletSignature: Bool

        public struct TypedData: Decodable {
            public let domain: Domain
            public let types: [String: [TypeField]]
            public let primaryType: String
            public let message: AnyCodable

            public struct Domain: Decodable {
                public let name: String
                public let version: String
                public let chainId: Int
                public let verifyingContract: String
                public let salt: String?
            }

            public struct TypeField: Decodable {
                public let name: String
                public let type: String
            }
        }
    }
}
