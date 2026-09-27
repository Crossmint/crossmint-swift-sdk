import CrossmintCommonTypes
import Foundation
import Logger

struct WalletSignerConfigApiModel: Decodable, Sendable {
    let locator: SignerLocator
}

struct RecoveryMethodApiModel {
    let signer: AdminSignerApiModel
    let status: SignerStatus

    var toDomain: RecoveryMethod {
        RecoveryMethod(signer: signer.toDomain, status: status)
    }
}

public struct WalletConfigApiModel: Decodable {
    public let adminSigner: AdminSignerApiModel
    let recoveryMethods: [RecoveryMethodApiModel]?
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
        let adminSignerType = try Self.rawSignerType(from: adminSignerDecoder)
        if AdminSignerDataType(rawValue: adminSignerType) == nil, let fallback = recoveryMethods?.first {
            Logger.smartWallet.warning(LogEvents.walletConfigAdminSignerFallback, attributes: [
                "type": adminSignerType
            ])
            adminSigner = fallback.signer
        } else {
            adminSigner = try Self.decodeSigner(from: adminSignerDecoder)
        }

        signers = try container.decodeIfPresent([WalletSignerConfigApiModel].self, forKey: .signers)
    }

    private enum AdminSignerCodingKeys: String, CodingKey {
        case type
    }

    private enum RecoveryMethodCodingKeys: String, CodingKey {
        case status
    }

    private static func decodeRecoveryMethods(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> [RecoveryMethodApiModel]? {
        guard container.contains(.recoveryMethods) else { return nil }
        var list = try container.nestedUnkeyedContainer(forKey: .recoveryMethods)
        var methods: [RecoveryMethodApiModel] = []
        while !list.isAtEnd {
            let entry = try list.superDecoder()
            let rawType = try rawSignerType(from: entry)
            guard AdminSignerDataType(rawValue: rawType) != nil else {
                Logger.smartWallet.warning(LogEvents.walletConfigRecoverySignerSkipped, attributes: [
                    "type": rawType
                ])
                continue
            }
            let status = try entry.container(keyedBy: RecoveryMethodCodingKeys.self)
                .decodeIfPresent(SignerStatus.self, forKey: .status)
            let signer = try decodeSigner(from: entry)
            methods.append(RecoveryMethodApiModel(signer: signer, status: status ?? .unknown))
        }
        return methods
    }

    private static func rawSignerType(from decoder: Decoder) throws -> String {
        let typeContainer = try decoder.container(keyedBy: AdminSignerCodingKeys.self)
        return try typeContainer.decode(String.self, forKey: .type)
    }

    private static func decodeSigner(from decoder: Decoder) throws -> AdminSignerApiModel {
        let typeContainer = try decoder.container(keyedBy: AdminSignerCodingKeys.self)
        let rawType = try rawSignerType(from: decoder)
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
