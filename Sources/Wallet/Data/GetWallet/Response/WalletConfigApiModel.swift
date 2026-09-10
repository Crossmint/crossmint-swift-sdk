import CrossmintCommonTypes
import Foundation

struct WalletSignerConfigApiModel: Decodable, Sendable {
    let locator: SignerLocator
}

public struct WalletConfigApiModel: Decodable {
    /// Every recovery signer of the wallet, in the order the backend reports them.
    ///
    /// Solana and Stellar wallets report the full list under `recovery`. EVM wallets report only
    /// `adminSigner`, so the list has exactly one entry there.
    public let recoveryMethods: [AdminSignerApiModel]
    let signers: [WalletSignerConfigApiModel]?

    /// The first recovery signer.
    public var recovery: AdminSignerApiModel { recoveryMethods[0] }

    enum CodingKeys: String, CodingKey {
        case adminSigner
        case recovery
        case signers = "delegatedSigners"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        var methods: [AdminSignerApiModel] = []
        if container.contains(.recovery) {
            var list = try container.nestedUnkeyedContainer(forKey: .recovery)
            while !list.isAtEnd {
                methods.append(try Self.decodeSigner(from: list.superDecoder()))
            }
        }
        if methods.isEmpty {
            methods = [try Self.decodeSigner(from: container.superDecoder(forKey: .adminSigner))]
        }

        recoveryMethods = methods
        signers = try container.decodeIfPresent([WalletSignerConfigApiModel].self, forKey: .signers)
    }

    private enum AdminSignerCodingKeys: String, CodingKey {
        case type
    }

    private static func decodeSigner(from decoder: Decoder) throws -> AdminSignerApiModel {
        let typeContainer = try decoder.container(keyedBy: AdminSignerCodingKeys.self)
        let type = try typeContainer.decode(AdminSignerDataType.self, forKey: .type)

        switch type {
        case .passkey:
            return try EvmPasskeySignerApiModel(from: decoder)
        case .email:
            return try EmailSignerApiModel(from: decoder)
        case .phone:
            return try PhoneSignerApiModel(from: decoder)
        case .apiKey:
            return try ApiKeySignerApiModel(from: decoder)
        case .externalWallet:
            return try ExternalWalletSignerApiModel(from: decoder)
        case .server:
            return try ServerSignerApiModel(from: decoder)
        }
    }

    var toDomain: WalletConfig {
        WalletConfig(recoveryMethods: recoveryMethods.map(\.toDomain))
    }
}
