import CrossmintCommonTypes
import Foundation

public struct SignMessageRequest: Encodable {
    public let type: String = "message"
    public let params: Params

    public struct Params: Encodable {
        public let message: String
        public let chain: Chain
        public let signer: (any AdminSignerData)?
        let isSmartWalletSignature: Bool

        public init(
            message: String,
            chain: Chain,
            signer: (any AdminSignerData)? = nil,
            isSmartWalletSignature: Bool = true
        ) {
            self.message = message
            self.chain = chain
            self.signer = signer
            self.isSmartWalletSignature = isSmartWalletSignature
        }

        private enum CodingKeys: String, CodingKey {
            case message
            case chain
            case signer
            case isSmartWalletSignature
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(message, forKey: .message)
            try container.encode(chain, forKey: .chain)

            // Encode signer as its locator string
            if let signer = signer {
                try container.encode(signer.locator, forKey: .signer)
            } else {
                try container.encodeNil(forKey: .signer)
            }

            try container.encode(isSmartWalletSignature, forKey: .isSmartWalletSignature)
        }
    }

    public init(params: Params) {
        self.params = params
    }
}
