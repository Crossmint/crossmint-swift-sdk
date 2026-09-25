import CrossmintCommonTypes
import Foundation

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

        adminSigner = try Self.decodeSigner(from: container.superDecoder(forKey: .adminSigner))
        if container.contains(.recoveryMethods) {
            var list = try container.nestedUnkeyedContainer(forKey: .recoveryMethods)
            var methods: [RecoveryMethodApiModel] = []
            while !list.isAtEnd {
                let entry = try list.superDecoder()
                let status = try entry.container(keyedBy: RecoveryMethodCodingKeys.self)
                    .decodeIfPresent(SignerStatus.self, forKey: .status)
                let signer = try Self.decodeSigner(from: entry)
                methods.append(RecoveryMethodApiModel(signer: signer, status: status ?? .unknown))
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

    private enum RecoveryMethodCodingKeys: String, CodingKey {
        case status
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
        guard let recoveryMethods, let first = recoveryMethods.first else {
            return WalletConfig(recovery: adminSigner.toDomain)
        }
        return WalletConfig(recovery: first.toDomain, others: recoveryMethods.dropFirst().map(\.toDomain))
    }
}
