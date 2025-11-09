public enum Owner: Sendable, Codable, CustomStringConvertible {
    case email(String)
    case userId(String)
    case phoneNumber(String)
    case twitter(String)
    case x(String)

    public var description: String {
        switch self {
        case let .email(email):
            "email:\(email)"
        case let .userId(id):
            "userId:\(id)"
        case let .phoneNumber(number):
            "phoneNumber:\(number)"
        case let .twitter(handle):
            "twitter:\(handle)"
        case let .x(handle):
            "x:\(handle)"
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = try Owner(from: value)
    }

    public init(from locator: String) throws {
        let components = locator.split(separator: ":", maxSplits: 1)
        guard components.count == 2 else {
            throw LinkedUserError.invalidLocator(locator)
        }

        let type = String(components[0])
        let content = String(components[1])

        switch type {
        case "email": self = .email(content)
        case "userId": self = .userId(content)
        case "phoneNumber": self = .phoneNumber(content)
        case "twitter": self = .twitter(content)
        case "x": self = .x(content)
        default:
            throw LinkedUserError.unknownType(type)
        }
    }
}
