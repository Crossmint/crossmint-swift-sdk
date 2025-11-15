extension Chain: Codable {
    public static func fromName(_ name: String) -> Chain? {
        Chain(name)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let name = try container.decode(String.self)
        self = Self.fromName(name) ?? .unknown(name: name)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(name)
    }
}
