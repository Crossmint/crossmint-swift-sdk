import CrossmintCommonTypes
import Utils
import Foundation

public struct SignTypedDataRequest: Encodable {
    public struct TypedData: Encodable {
        public struct Domain: Encodable {
            public let name: String
            public let version: String
            public let chainId: Int
            public let verifyingContract: String
            public let salt: String?

            public init(
                name: String,
                version: String,
                chainId: Int,
                verifyingContract: String,
                salt: String? = nil
            ) {
                self.name = name
                self.version = version
                self.chainId = chainId
                self.verifyingContract = verifyingContract
                self.salt = salt
            }
        }

        public struct Types: Encodable {

        }

        public let domain: Domain
        public let types: [String: [[String: String]]]
        public let primaryType: String
        public let message: [String: any Encodable]

        public init(
            domain: Domain,
            types: [String: [[String: String]]],
            primaryType: String,
            message: [String: any Encodable]
        ) {
            self.domain = domain
            self.types = types
            self.primaryType = primaryType
            self.message = message
        }

        private enum CodingKeys: String, CodingKey {
            case domain, types, primaryType, message
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(domain, forKey: .domain)
            try container.encode(types, forKey: .types)
            try container.encode(primaryType, forKey: .primaryType)
            let codableMessage = message.mapValues(AnyCodable.init)
            try container.encode(codableMessage, forKey: .message)
        }
    }

    public let type: String = "typed-data"
    public let params: Params

    public struct Params: Encodable {
        public let typedData: TypedData
        public let chain: Chain
        public let signer: (any AdminSignerData)?
        public let isSmartWalletSignature: Bool

        public init(
            typedData: TypedData,
            chain: Chain,
            signer: (any AdminSignerData)? = nil,
            isSmartWalletSignature: Bool = false
        ) {
            self.typedData = typedData
            self.chain = chain
            self.signer = signer
            self.isSmartWalletSignature = isSmartWalletSignature
        }

        private enum CodingKeys: String, CodingKey {
            case typedData
            case chain
            case signer
            case isSmartWalletSignature
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(typedData, forKey: .typedData)
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
