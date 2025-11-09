import CrossmintCommonTypes

public struct OrderFiatPaymentFailureReason: Codable, Sendable {
    public var code: String
    public var message: String?
}

public struct OrderCryptoPaymentFailureReason: Codable, Sendable {
    public var code: CryptoPaymentFailureCode
    public var message: String?
}

public enum OrderPaymentFailureReason: Codable, Sendable {
    case fiat(OrderFiatPaymentFailureReason)
    case crypto(OrderCryptoPaymentFailureReason)
}
