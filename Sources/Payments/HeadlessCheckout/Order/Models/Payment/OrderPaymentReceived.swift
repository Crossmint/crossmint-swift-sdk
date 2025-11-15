import CrossmintCommonTypes
import Foundation

public struct FiatOrderPayment: Codable, Sendable {
    public var amount: String
    public var currency: Currency
}

public struct CryptoOrderPayment: Codable, Sendable {
    public var txId: String
    public var chain: Chain
}

public enum OrderPaymentReceived: Codable, Sendable {
    case crypto(CryptoOrderPayment)
    case fiat(FiatOrderPayment)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let crypto: CryptoOrderPayment = try? container.decode(CryptoOrderPayment.self) {
            self = .crypto(crypto)
        } else if let fiat: FiatOrderPayment = try? container.decode(FiatOrderPayment.self) {
            self = .fiat(fiat)
        } else {
            throw DecodingError.typeMismatch(
                OrderPaymentReceived.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot decode OrderPaymentReceived"
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
