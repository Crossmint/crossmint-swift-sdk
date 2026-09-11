import CrossmintCommonTypes
import Foundation

public struct DelegatedSignerEntry: Encodable {
    public enum Signer: Encodable, Equatable {
        case locator(SignerLocator)
        case device(publicKey: DevicePublicKey, name: String)

        public func encode(to encoder: Encoder) throws {
            switch self {
            case let .locator(locator):
                var container = encoder.singleValueContainer()
                try container.encode(locator)
            case let .device(publicKey, name):
                var container = encoder.container(keyedBy: DeviceCodingKeys.self)
                try container.encode("device", forKey: .type)
                try container.encode(publicKey, forKey: .publicKey)
                try container.encode(name, forKey: .name)
            }
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
        let recovery: [AdminSignerRequestApiModel]?
        let delegatedSigners: [DelegatedSignerEntry]?

        init(adminSigner: any AdminSignerData, delegatedSigners: [DelegatedSignerEntry]?) {
            self.adminSigner = AdminSignerRequestApiModel(adminSigner)
            self.recovery = nil
            self.delegatedSigners = delegatedSigners
        }

        init(recovery: [any AdminSignerData], delegatedSigners: [DelegatedSignerEntry]?) {
            self.adminSigner = nil
            self.recovery = recovery.map(AdminSignerRequestApiModel.init)
            self.delegatedSigners = delegatedSigners
        }

        private enum CodingKeys: String, CodingKey {
            case adminSigner, recovery, delegatedSigners
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(adminSigner, forKey: .adminSigner)
            try container.encodeIfPresent(recovery, forKey: .recovery)
            try container.encodeIfPresent(delegatedSigners, forKey: .delegatedSigners)
        }
    }

    let chainType: ChainType
    let type: WalletType
    let config: InputConfig
}
