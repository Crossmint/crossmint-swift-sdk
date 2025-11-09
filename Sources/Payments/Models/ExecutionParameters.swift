import Utils

public struct ExecutionParameters: Codable, Sendable {
    private var storage: [String: AnyCodable]

    public init(_ dictionary: [String: any Sendable] = [:]) {
        self.storage = dictionary.mapValues { AnyCodable($0) }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        storage = try container.decode([String: AnyCodable].self)
    }

    public subscript(_ key: String) -> (any Sendable)? {
        get { storage[key]?.value }
        set { storage[key] = newValue.map { AnyCodable($0) } }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storage)
    }
}
