public protocol AdminSignerData: Sendable, Codable {
    var type: AdminSignerDataType { get }
    var locatorId: String { get }
}

public enum AdminSignerDataType: String, Sendable, Codable {
    case email
    case apiKey = "api-key"
    case passkey
    case externalWallet = "external-wallet"
    case phone
}

public extension AdminSignerData {
    var locator: String {
        "\(type.rawValue):\(locatorId)"
    }
}

public struct ExternalWalletSignerData: AdminSignerData {
    public let address: String

    public var type: AdminSignerDataType {
        .externalWallet
    }

    public var locatorId: String {
        address
    }

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
        guard type == AdminSignerDataType.externalWallet.rawValue else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Expected signer type to be \(AdminSignerDataType.externalWallet.rawValue) but found \(type)"
            )
        }
        self.address = try container.decode(String.self, forKey: .address)
    }
}

public struct ApiKeySignerData: AdminSignerData {
    public var type: AdminSignerDataType {
        .apiKey
    }

    public var locatorId: String {
        "api-key"
    }

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case type
    }

    public nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type.rawValue, forKey: .type)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        guard type == AdminSignerDataType.apiKey.rawValue else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Expected signer type to be \(AdminSignerDataType.apiKey.rawValue) but found \(type)"
            )
        }
    }
}

public struct PasskeySignerData: AdminSignerData {
    public struct PublicKey: Sendable, Codable {
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

    public var type: AdminSignerDataType {
        .passkey
    }

    public var locatorId: String {
        id
    }

    public init(id: String, name: String, publicKey: PublicKey, validatorContractVersion: String? = nil) {
        self.id = id
        self.name = name
        self.publicKey = publicKey
        self.validatorContractVersion = validatorContractVersion
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case name
        case publicKey
        case validatorContractVersion
    }

    public nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type.rawValue, forKey: .type)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(publicKey, forKey: .publicKey)
        try container.encodeIfPresent(validatorContractVersion, forKey: .validatorContractVersion)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        guard type == AdminSignerDataType.passkey.rawValue else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Expected signer type to be \(AdminSignerDataType.passkey.rawValue) but found \(type)"
            )
        }
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.publicKey = try container.decode(PublicKey.self, forKey: .publicKey)
        self.validatorContractVersion = try container.decodeIfPresent(String.self, forKey: .validatorContractVersion)
    }
}

public struct EmailSignerData: AdminSignerData {
    public let email: String

    public var type: AdminSignerDataType {
        .email
    }

    public var locatorId: String {
        email
    }

    public init(email: String) {
        self.email = email
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case email
    }

    public nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type.rawValue, forKey: .type)
        try container.encode(email, forKey: .email)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        guard type == AdminSignerDataType.email.rawValue else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Expected signer type to be \(AdminSignerDataType.email.rawValue) but found \(type)"
            )
        }
        self.email = try container.decode(String.self, forKey: .email)
    }
}

public struct PhoneSignerData: AdminSignerData {
    public let phone: String

    public var type: AdminSignerDataType {
        .phone
    }

    public var locatorId: String {
        phone
    }

    public init(phone: String) {
        self.phone = phone
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case phone
    }

    public nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type.rawValue, forKey: .type)
        try container.encode(phone, forKey: .phone)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        guard type == AdminSignerDataType.phone.rawValue else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Expected signer type to be \(AdminSignerDataType.phone.rawValue) but found \(type)"
            )
        }
        self.phone = try container.decode(String.self, forKey: .phone)
    }
}
