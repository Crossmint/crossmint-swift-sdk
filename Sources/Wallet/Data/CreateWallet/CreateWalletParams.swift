import CrossmintCommonTypes
import Passkeys

public struct DelegatedSignerEntry: Encodable {
    public let signer: String  // e.g. "device:<base64_uncompressed_pubkey>"
}

public struct CreateWalletParams: Encodable {
    struct InputConfig: Encodable {
        let adminSigner: any AdminSignerData
        let delegatedSigners: [DelegatedSignerEntry]?

        enum CodingKeys: String, CodingKey {
            case adminSigner
            case delegatedSigners
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(adminSigner, forKey: .adminSigner)
            if let delegatedSigners {
                try container.encode(delegatedSigners, forKey: .delegatedSigners)
            }
        }
    }

    let chainType: ChainType
    let type: WalletType
    let config: InputConfig
}
