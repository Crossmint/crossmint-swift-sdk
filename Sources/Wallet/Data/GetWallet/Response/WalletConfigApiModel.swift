import CrossmintCommonTypes
import Foundation

struct WalletSignerConfigApiModel: Decodable, Sendable {
    let locator: SignerLocator
}

public struct WalletConfigApiModel: Decodable {
    public let recovery: AdminSignerApiModel
    let recoveryMethods: [AdminSignerApiModel]?
    let signers: [WalletSignerConfigApiModel]?

    enum CodingKeys: String, CodingKey {
        case recovery = "adminSigner"
        case recoveryMethods = "recovery"
        case signers = "delegatedSigners"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        recovery = try Self.decodeSigner(from: container.superDecoder(forKey: .recovery))
        if container.contains(.recoveryMethods) {
            var list = try container.nestedUnkeyedContainer(forKey: .recoveryMethods)
            var methods: [AdminSignerApiModel] = []
            while !list.isAtEnd {
                methods.append(try Self.decodeSigner(from: list.superDecoder()))
            }
            recoveryMethods = methods
        } else {
            recoveryMethods = nil
        }
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
        let all = recoveryMethods ?? [recovery]
        return WalletConfig(
            recovery: (all.first ?? recovery).toDomain,
            otherRecoveryMethods: all.dropFirst().map(\.toDomain)
        )
    }
}
