import CrossmintCommonTypes

public enum StripeFiatPaymentMethod: String, Codable, Sendable {
    case stripePaymentElement = "stripe-payment-element"
}

public enum CheckoutComFiatPaymentMethod: String, Codable, Sendable {
    case checkoutComFlow = "checkoutcom-flow"
}

public enum SolanaChain: String, Codable, Sendable {
    case solana
}

public enum OrderCryptoPaymentMethod: Codable, Sendable {
    case evm(EVMChain)
    case solana(SolanaChain)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let evm = try? container.decode(EVMChain.self) {
            self = .evm(evm)
        } else if let solana = try? container.decode(SolanaChain.self) {
            self = .solana(solana)
        } else {
            throw DecodingError.typeMismatch(
                OrderCryptoPaymentMethod.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid OrderCryptoPaymentMethod")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .evm(let evm): try container.encode(evm)
        case .solana: try container.encodeNil()
        }
    }

    public var blockChainCopy: String {
        switch self {
        case .evm: return "EVM"
        case .solana: return "Solana"
        }
    }
}

public enum OrderFiatPaymentMethod: Codable, Sendable {
    case stripe(StripeFiatPaymentMethod)
    case checkoutCom(CheckoutComFiatPaymentMethod)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stripe = try? container.decode(StripeFiatPaymentMethod.self) {
            self = .stripe(stripe)
        } else if let checkoutcom = try? container.decode(CheckoutComFiatPaymentMethod.self) {
            self = .checkoutCom(checkoutcom)
        } else {
            throw DecodingError.typeMismatch(
                OrderFiatPaymentMethod.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid OrderFiatPaymentMethod")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .stripe(let stripe): try container.encode(stripe)
        case .checkoutCom(let checkoutcom): try container.encode(checkoutcom)
        }
    }

    public var isCheckoutCom: Bool {
        switch self {
        case .checkoutCom: return true
        default: return false
        }
    }

    public var isStripe: Bool {
        switch self {
        case .stripe: return true
        default: return false
        }
    }
}

public enum OrderPaymentMethod: Codable, Sendable {
    case fiat(OrderFiatPaymentMethod)
    case crypto(OrderCryptoPaymentMethod)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let fiat = try? container.decode(OrderFiatPaymentMethod.self) {
            self = .fiat(fiat)
        } else if let crypto = try? container.decode(OrderCryptoPaymentMethod.self) {
            self = .crypto(crypto)
        } else {
            throw DecodingError.typeMismatch(
                OrderPaymentMethod.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath, debugDescription: "Invalid OrderPaymentMethod")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .fiat(let fiat): try container.encode(fiat)
        case .crypto(let crypto): try container.encode(crypto)
        }
    }

    public var isFiat: Bool {
        if case .fiat = self {
            return true
        }

        return false
    }

    public var isCrypto: Bool {
        if case .crypto = self {
            return true
        }

        return false
    }
}
