import CrossmintCommonTypes
import Foundation

public struct DelegatedSignerEntry: Encodable {
    public enum Signer: Encodable, Equatable {
        case locator(SignerLocator)
        case device(publicKey: DevicePublicKey, name: String)
        case passkey(PasskeySignerData)
        indirect case quorum(threshold: Int, members: [Signer])

        public func encode(to encoder: Encoder) throws {
            switch self {
            case let .quorum(threshold, members):
                var container = encoder.container(keyedBy: QuorumCodingKeys.self)
                try container.encode("quorum", forKey: .type)
                try container.encode(threshold, forKey: .threshold)
                var list = container.nestedUnkeyedContainer(forKey: .members)
                for member in members {
                    if case let .locator(locator) = member, let data = locator.memberData {
                        try list.encode(AdminSignerRequestApiModel(data))
                    } else {
                        try list.encode(member)
                    }
                }
            case let .locator(locator):
                var container = encoder.singleValueContainer()
                try container.encode(locator)
            case let .passkey(data):
                var container = encoder.singleValueContainer()
                try container.encode(AdminSignerRequestApiModel(data))
            case let .device(publicKey, name):
                var container = encoder.container(keyedBy: DeviceCodingKeys.self)
                try container.encode("device", forKey: .type)
                try container.encode(publicKey, forKey: .publicKey)
                try container.encode(name, forKey: .name)
            }
        }

        private enum QuorumCodingKeys: String, CodingKey {
            case type
            case threshold
            case members
        }

        private enum DeviceCodingKeys: String, CodingKey {
            case type
            case publicKey
            case name
        }
    }

    public let signer: Signer
}

public struct DevicePublicKey: Encodable, Equatable {
    public let x: String
    public let y: String

    /// Splits a base64-encoded 65-byte uncompressed P-256 public key (0x04 ‖ x ‖ y)
    /// into its `0x`-prefixed hex coordinates. Fails when the key is not in that format.
    public init?(publicKeyBase64: String) {
        guard let rawKey = Data(base64Encoded: publicKeyBase64),
              rawKey.count == 65, rawKey[0] == 0x04 else {
            return nil
        }
        x = Self.hexCoordinate(rawKey[1..<33])
        y = Self.hexCoordinate(rawKey[33..<65])
    }

    private static func hexCoordinate(_ bytes: Data) -> String {
        "0x" + bytes.map { String(format: "%02x", $0) }.joined()
    }
}

public struct CreateWalletParams: Encodable {
    struct InputConfig: Encodable {
        let adminSigner: AdminSignerRequestApiModel?
        let recoveryMethods: [AdminSignerRequestApiModel]?
        let delegatedSigners: [DelegatedSignerEntry]?

        init(adminSigner: any AdminSignerData, delegatedSigners: [DelegatedSignerEntry]?) {
            self.adminSigner = AdminSignerRequestApiModel(adminSigner)
            self.recoveryMethods = nil
            self.delegatedSigners = delegatedSigners
        }

        init(recoveryMethods: [any AdminSignerData], delegatedSigners: [DelegatedSignerEntry]?) {
            self.adminSigner = nil
            self.recoveryMethods = recoveryMethods.map(AdminSignerRequestApiModel.init)
            self.delegatedSigners = delegatedSigners
        }

        private enum CodingKeys: String, CodingKey {
            case adminSigner, recoveryMethods, delegatedSigners
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(adminSigner, forKey: .adminSigner)
            try container.encodeIfPresent(recoveryMethods, forKey: .recoveryMethods)
            try container.encodeIfPresent(delegatedSigners, forKey: .delegatedSigners)
        }
    }

    let chainType: ChainType
    let type: WalletType
    let config: InputConfig
}

private extension SignerLocator {
    var memberData: (any AdminSignerData)? {
        switch self {
        case .email(let email): EmailSignerData(email: email)
        case .phone(let phone): PhoneSignerData(phone: phone)
        case .externalWallet(let address): ExternalWalletSignerData(address: address)
        default: nil
        }
    }
}

extension DelegatedSignerEntry.Signer {
    static func registration(of config: SignerConfig) throws(WalletError) -> Self? {
        guard case .quorum = config else { return config.locator.map { .locator($0) } }
        return try quorum(from: config)
    }

    static func quorum(from config: SignerConfig) throws(WalletError) -> Self {
        guard case let .quorum(threshold, members) = config else {
            throw .walletGeneric("The signer is not a quorum.")
        }
        guard !members.isEmpty else {
            throw .walletGeneric("The quorum has no members.")
        }
        var memberSigners: [Self] = []
        for member in members {
            switch member {
            case .email, .phone, .externalWallet:
                guard let locator = member.locator else { continue }
                memberSigners.append(.locator(locator))
            case .passkey, .apiKey, .device, .quorum:
                throw .walletGeneric("The members of a quorum signer must be email, phone or external wallet signers.")
            }
        }
        return .quorum(threshold: threshold, members: memberSigners)
    }
}
