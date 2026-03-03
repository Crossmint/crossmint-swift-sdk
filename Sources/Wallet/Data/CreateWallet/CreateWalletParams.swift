import CrossmintCommonTypes
import Passkeys

public struct DelegatedSignerPublicKey: Encodable {
    public let x: String
    public let y: String
}

public struct DelegatedSignerData: Encodable {
    public let type: String = "device"
    public let publicKey: DelegatedSignerPublicKey
}

public struct DelegatedSignerEntry: Encodable {
    public let signer: DelegatedSignerData
}

public struct CreateWalletParams: Encodable {
    struct InputConfig: Encodable {
        let adminSigner: any AdminSignerData

        enum CodingKeys: String, CodingKey {
            case adminSigner
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(adminSigner, forKey: .adminSigner)
        }
    }

    let chainType: ChainType
    let type: WalletType
    let config: InputConfig
    let delegatedSigners: [DelegatedSignerEntry]?
}
