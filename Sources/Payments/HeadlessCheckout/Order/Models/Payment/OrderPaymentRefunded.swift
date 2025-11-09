import CrossmintCommonTypes
import Foundation

public struct FiatOrderPaymentRefunded: Codable, Sendable {
    public var amount: String
    public var currency: Currency
}

public struct CryptoOrderPaymentRefunded: Codable, Sendable {
    public var txId: String
    public var chain: Chain
}

public enum OrderPaymentRefunded: Codable, Sendable {
    case crypto(CryptoOrderPaymentRefunded)
    case fiat(FiatOrderPaymentRefunded)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let crypto = try? container.decode(CryptoOrderPaymentRefunded.self) {
            self = .crypto(crypto)
        } else if let fiat = try? container.decode(FiatOrderPaymentRefunded.self) {
            self = .fiat(fiat)
        } else {
            throw DecodingError.typeMismatch(
                OrderPaymentRefunded.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot decode OrderPaymentRefunded"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .crypto(let crypto):
            try container.encode(crypto)
        case .fiat(let fiat):
            try container.encode(fiat)
        }
    }
}
