import Foundation
import CrossmintCommonTypes

public struct WalletApiModel: Decodable {
    public let owner: Owner?
    public let address: String
    public let type: WalletType
    public let chainType: ChainType
    public let createdAt: Date
    public let config: WalletConfigApiModel

    private enum CodingKeys: String, CodingKey {
        case owner = "linkedUser"
        case address
        case type
        case chainType
        case createdAt
        case config
    }
}
