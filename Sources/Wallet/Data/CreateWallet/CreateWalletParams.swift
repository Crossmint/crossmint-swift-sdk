import CrossmintCommonTypes
import Passkeys

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
}
