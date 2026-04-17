public protocol AdminSignerData: Sendable {
    var type: AdminSignerDataType { get }
    var locatorId: String { get }
}

public enum AdminSignerDataType: String, Sendable, Codable {
    case email
    case apiKey = "api-key"
    case passkey
    case externalWallet = "external-wallet"
    case phone
    case server
}

public extension AdminSignerData {
    var locator: String {
        "\(type.rawValue):\(locatorId)"
    }
}

public struct ExternalWalletSignerData: AdminSignerData {
    public let address: String

    public var type: AdminSignerDataType { .externalWallet }
    public var locatorId: String { address }

    public init(address: String) {
        self.address = address
    }
}

public struct ApiKeySignerData: AdminSignerData {
    public let address: String?

    public var type: AdminSignerDataType { .apiKey }
    public var locatorId: String { address ?? type.rawValue }

    public init(address: String? = nil) {
        self.address = address
    }
}

public struct PasskeySignerData: AdminSignerData {
    public struct PublicKey: Sendable {
        public let x: String
        public let y: String

        public init(x: String, y: String) {
            self.x = x
            self.y = y
        }
    }

    public let id: String
    public let name: String
    public let publicKey: PublicKey
    public let validatorContractVersion: String?

    public var type: AdminSignerDataType { .passkey }
    public var locatorId: String { id }

    public init(id: String, name: String, publicKey: PublicKey, validatorContractVersion: String? = nil) {
        self.id = id
        self.name = name
        self.publicKey = publicKey
        self.validatorContractVersion = validatorContractVersion
    }
}

public struct EmailSignerData: AdminSignerData {
    public let email: String

    public var type: AdminSignerDataType { .email }
    public var locatorId: String { email }

    public init(email: String) {
        self.email = email
    }
}

public struct PhoneSignerData: AdminSignerData {
    public let phone: String

    public var type: AdminSignerDataType { .phone }
    public var locatorId: String { phone }

    public init(phone: String) {
        self.phone = phone
    }
}

public struct ServerSignerData: AdminSignerData {
    public let address: String

    public var type: AdminSignerDataType { .server }

    public var locatorId: String { address }

    public init(address: String) {
        self.address = address
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case address
    }

    public nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type.rawValue, forKey: .type)
        try container.encode(address, forKey: .address)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        guard type == AdminSignerDataType.server.rawValue else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Expected signer type to be \(AdminSignerDataType.server.rawValue) but found \(type)"
            )
        }
        self.address = try container.decode(String.self, forKey: .address)
    }
}
