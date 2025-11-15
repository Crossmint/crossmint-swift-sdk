import Foundation
import Utils

public protocol BaseSolanaLineItemDeliveryToken: CommonLineItemDeliveryToken {
    var mintHash: String { get set }
}

public struct ExactOutSolanaLineItemDeliveryToken: BaseSolanaLineItemDeliveryToken {
    public var locator: TokenLocator
    public var mintHash: String
}

public struct ExactInSolanaLineItemDeliveryToken: BaseSolanaLineItemDeliveryToken {
    public var locator: TokenLocator
    public var mintHash: String
    public var quantity: String
}

public enum SolanaLineItemDeliveryToken: Codable, Sendable {
    case exactOut(ExactOutSolanaLineItemDeliveryToken)
    case exactIn(ExactInSolanaLineItemDeliveryToken)

    public init(from decoder: Decoder) throws {
        let lineItemDeliveryToken: SolanaLineItemDeliveryToken? = try? when(
            decoder, containsKey: "quantity"
        )
        .decodeItAs(ExactInSolanaLineItemDeliveryToken.self, andRun: { .exactIn($0) })
        .elseDecodeItAs(ExactOutSolanaLineItemDeliveryToken.self, andRun: { .exactOut($0) })
        .value

        guard let token = lineItemDeliveryToken else {
            throw DecodingError.typeMismatch(
                SolanaLineItemDeliveryToken.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid SolanaLineItemDeliveryToken")
            )
        }
        self = token
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .exactOut(let exactOut): try container.encode(exactOut)
        case .exactIn(let exactIn): try container.encode(exactIn)
        }
    }

    public var exactOut: ExactOutSolanaLineItemDeliveryToken? {
        switch self {
        case .exactOut(let exactOut): return exactOut
        default: return nil
        }
    }

    public var exactIn: ExactInSolanaLineItemDeliveryToken? {
        switch self {
        case .exactIn(let exactIn): return exactIn
        default: return nil
        }
    }
}
