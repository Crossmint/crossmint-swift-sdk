public struct OrderPayment: Codable, Sendable {
    public var status: OrderPaymentStatus
    public var failureReason: OrderPaymentFailureReason?
    public var method: OrderPaymentMethod
    public var currency: Currency
    public var paymentStage: OrderPaymentStage = .none
    public var receiptEmail: String?

    enum CodingKeys: String, CodingKey {
        case status, failureReason, method, currency, preparation, received, refunded, receiptEmail
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        status = try container.decode(OrderPaymentStatus.self, forKey: .status)
        failureReason = try container.decodeIfPresent(
            OrderPaymentFailureReason.self, forKey: .failureReason)
        method = try container.decode(OrderPaymentMethod.self, forKey: .method)
        currency = try container.decode(Currency.self, forKey: .currency)
        receiptEmail = try container.decodeIfPresent(String.self, forKey: .receiptEmail)

        // Determine which stage we're in based on the JSON fields
        let preparation = try container.decodeIfPresent(
            OrderPaymentPreparation.self, forKey: .preparation)
        let received = try container.decodeIfPresent(OrderPaymentReceived.self, forKey: .received)
        let refunded = try container.decodeIfPresent(OrderPaymentRefunded.self, forKey: .refunded)

        if let preparation = preparation {
            paymentStage = .preparation(preparation)
        } else if let received = received {
            paymentStage = .received(received)
        } else if let refunded = refunded {
            paymentStage = .refunded(refunded)
        } else {
            paymentStage = .none
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(failureReason, forKey: .failureReason)
        try container.encode(method, forKey: .method)
        try container.encode(currency, forKey: .currency)
        try container.encodeIfPresent(receiptEmail, forKey: .receiptEmail)

        // Encode the appropriate field based on the stage
        switch paymentStage {
        case .preparation(let prep):
            try container.encode(prep, forKey: .preparation)
        case .received(let rec):
            try container.encode(rec, forKey: .received)
        case .refunded(let ref):
            try container.encode(ref, forKey: .refunded)
        case .none:
            break
        }
    }

    public var preparation: OrderPaymentPreparation? {
        switch paymentStage {
        case .preparation(let prep): return prep
        default: return nil
        }
    }

    public var received: OrderPaymentReceived? {
        switch paymentStage {
        case .received(let rec): return rec
        default: return nil
        }
    }

    public var refunded: OrderPaymentRefunded? {
        switch paymentStage {
        case .refunded(let ref): return ref
        default: return nil
        }
    }
}
