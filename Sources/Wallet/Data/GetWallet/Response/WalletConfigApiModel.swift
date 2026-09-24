import CrossmintCommonTypes
import Foundation
import Logger

struct WalletSignerConfigApiModel: Decodable, Sendable {
    let locator: SignerLocator
}

public struct WalletConfigApiModel: Decodable {
    public let adminSigner: AdminSignerApiModel
    let recoveryMethods: [AdminSignerApiModel]?
    let signers: [WalletSignerConfigApiModel]?

    enum CodingKeys: String, CodingKey {
        case adminSigner
        case recoveryMethods
        case signers = "delegatedSigners"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let recoveryMethods = try Self.decodeRecoveryMethods(from: container)
        self.recoveryMethods = recoveryMethods

        let adminSignerDecoder = try container.superDecoder(forKey: .adminSigner)
        do {
            adminSigner = try Self.decodeSigner(from: adminSignerDecoder)
        } catch {
            guard let fallback = recoveryMethods?.first else { throw error }
            Logger.smartWallet.warning(LogEvents.walletConfigAdminSignerFallback, attributes: [
                "error": "\(error)"
            ])
            adminSigner = fallback
        }

        signers = try container.decodeIfPresent([WalletSignerConfigApiModel].self, forKey: .signers)
    }

    private enum AdminSignerCodingKeys: String, CodingKey {
        case type
    }

    private static func decodeRecoveryMethods(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> [AdminSignerApiModel]? {
        guard container.contains(.recoveryMethods) else { return nil }
        var list = try container.nestedUnkeyedContainer(forKey: .recoveryMethods)
        var methods: [AdminSignerApiModel] = []
        while !list.isAtEnd {
            let entryDecoder = try list.superDecoder()
            let typeContainer = try entryDecoder.container(keyedBy: AdminSignerCodingKeys.self)
            let rawType = try typeContainer.decode(String.self, forKey: .type)
            guard AdminSignerDataType(rawValue: rawType) != nil else {
                Logger.smartWallet.warning(LogEvents.walletConfigRecoverySignerSkipped, attributes: [
                    "type": rawType
                ])
                continue
            }
            methods.append(try decodeSigner(from: entryDecoder))
        }
        return methods
    }

    private static func decodeSigner(from decoder: Decoder) throws -> AdminSignerApiModel {
        let typeContainer = try decoder.container(keyedBy: AdminSignerCodingKeys.self)
        let rawType = try typeContainer.decode(String.self, forKey: .type)
        guard let type = AdminSignerDataType(rawValue: rawType) else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: typeContainer,
                debugDescription: "This SDK version does not support the signer type \"\(rawType)\""
            )
        }

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
        guard let recoveryMethods, let first = recoveryMethods.first else {
            return WalletConfig(recovery: adminSigner.toDomain)
        }
        return WalletConfig(recovery: first.toDomain, others: recoveryMethods.dropFirst().map(\.toDomain))
    }
}
