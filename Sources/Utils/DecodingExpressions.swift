import Foundation

public struct DecodingInitialExpression {
    let container: SingleValueDecodingContainer
    let valid: Bool

    public func decodeItAs<T, K>(
        _ t: T.Type,
        andRun block: ((T) -> K)
    ) throws -> DecodingIntermediateExpression<K> where T: Decodable {
        if valid {
            return DecodingIntermediateExpression(
                container: container,
                value: block(try container.decode(T.self))
            )
        } else {
            return DecodingIntermediateExpression(
                container: container,
                value: nil
            )
        }
    }
}

public struct DecodingIntermediateExpression<T> {
    private let container: SingleValueDecodingContainer
    public let value: T?

    public init(container: SingleValueDecodingContainer, value: T?) {
        self.container = container
        self.value = value
    }

    public func elseDecodeItAs<K>(
        _ k: K.Type,
        andRun block: ((K) -> T)
    ) throws -> DecodingIntermediateExpression<T> where K: Decodable {
        if value == nil {
            return DecodingIntermediateExpression(
                container: container,
                value: block(try container.decode(K.self))
            )
        } else {
            return self
        }
    }
}

public func when(_ decoder: Decoder, containsKey: String) throws -> DecodingInitialExpression {
    let container = try decoder.singleValueContainer()
    let raw = try container.decode([String: AnyCodable].self)

    return DecodingInitialExpression(container: container, valid: raw[containsKey] != nil)
}
