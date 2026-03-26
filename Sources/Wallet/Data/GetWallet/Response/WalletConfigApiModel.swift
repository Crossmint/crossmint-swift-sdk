import CrossmintCommonTypes
import Foundation

public struct WalletDelegatedSignerConfigApiModel: Decodable {
    public let locator: String?
    public let signer: String?
}

public struct WalletConfigApiModel: Decodable {
    public let recovery: AdminSignerApiModel
    public let signers: [WalletDelegatedSignerConfigApiModel]?

    enum CodingKeys: String, CodingKey {
        case recovery = "adminSigner"
        case signers = "delegatedSigners"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode the "type" field first to determine the correct signer type
        let tempContainer = try container.nestedContainer(keyedBy: AdminSignerCodingKeys.self, forKey: .recovery)
        let type = try tempContainer.decode(AdminSignerDataType.self, forKey: .type)

        switch type {
        case .passkey:
            recovery = try container.decode(EvmPasskeySignerApiModel.self, forKey: .recovery)
        case .email:
            recovery = try container.decode(EmailSignerApiModel.self, forKey: .recovery)
        case .phone:
            recovery = try container.decode(PhoneSignerApiModel.self, forKey: .recovery)
        case .apiKey:
            recovery = try container.decode(ApiKeySignerApiModel.self, forKey: .recovery)
        case .externalWallet:
            recovery = try container.decode(ExternalWalletSignerApiModel.self, forKey: .recovery)
        }

        signers = try container.decodeIfPresent([WalletDelegatedSignerConfigApiModel].self, forKey: .signers)
    }

    private enum AdminSignerCodingKeys: String, CodingKey {
        case type
    }

    var toDomain: WalletConfig {
        WalletConfig(recovery: recovery.toDomain)
    }
}
