import Foundation
import CrossmintCommonTypes

public struct MessageSignatureResponse: SignatureApiModel {
    public let id: String
    public let type: String
    public let chainType: String?
    public let walletType: String?
    public let status: String
    public let params: MessageParams
    public let approvals: Approvals
    public let createdAt: Date

    public struct MessageParams: Decodable {
        public let message: String
        public let chain: String
        public let signer: SignerApiModel
        public let isSmartWalletSignature: Bool?
    }
}
