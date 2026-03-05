import CrossmintCommonTypes
import Foundation

public struct WalletDelegatedSignerConfigApiModel: Decodable {
    public let locator: String?
    public let signer: String?
}

public struct WalletConfigApiModel: Decodable {
    public let adminSigner: AdminSignerApiModel
    public let delegatedSigners: [WalletDelegatedSignerConfigApiModel]?

    enum CodingKeys: String, CodingKey {
        case adminSigner
        case delegatedSigners
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode the "type" field first to determine the correct signer type
        let tempContainer = try container.nestedContainer(keyedBy: AdminSignerCodingKeys.self, forKey: .adminSigner)
        let type = try tempContainer.decode(AdminSignerDataType.self, forKey: .type)

        switch type {
        case .passkey:
            adminSigner = try container.decode(EvmPasskeySignerApiModel.self, forKey: .adminSigner)
        case .email:
            adminSigner = try container.decode(EmailSignerApiModel.self, forKey: .adminSigner)
        case .phone:
            adminSigner = try container.decode(PhoneSignerApiModel.self, forKey: .adminSigner)
        case .apiKey:
            adminSigner = try container.decode(ApiKeySignerApiModel.self, forKey: .adminSigner)
        case .externalWallet:
            adminSigner = try container.decode(ExternalWalletSignerApiModel.self, forKey: .adminSigner)
        }

        delegatedSigners = try container.decodeIfPresent([WalletDelegatedSignerConfigApiModel].self, forKey: .delegatedSigners)
    }

    private enum AdminSignerCodingKeys: String, CodingKey {
        case type
    }

    var toDomain: WalletConfig {
        WalletConfig(adminSigner: adminSigner.toDomain)
    }
}
