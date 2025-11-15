public enum LineItemDeliveryToken: Codable, Sendable {
    case evm(EvmLineItemDeliveryToken)
    case solana(SolanaLineItemDeliveryToken)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let evm = try? container.decode(EvmLineItemDeliveryToken.self) {
            self = .evm(evm)
        } else if let solana = try? container.decode(SolanaLineItemDeliveryToken.self) {
            self = .solana(solana)
        } else {
            throw DecodingError.typeMismatch(
                LineItemDeliveryToken.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid LineItemDeliveryToken")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .evm(let evm): try container.encode(evm)
        case .solana(let solana): try container.encode(solana)
        }
    }

    public var solana: SolanaLineItemDeliveryToken? {
        switch self {
        case .solana(let solana): return solana
        default: return nil
        }
    }

    public var evm: EvmLineItemDeliveryToken? {
        switch self {
        case .evm(let evm): return evm
        default: return nil
        }
    }
}
