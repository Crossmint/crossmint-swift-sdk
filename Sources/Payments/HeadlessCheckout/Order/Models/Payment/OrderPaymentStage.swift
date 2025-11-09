public enum OrderPaymentStage: Codable, Sendable {
    case preparation(OrderPaymentPreparation)
    case received(OrderPaymentReceived)
    case refunded(OrderPaymentRefunded)
    case none

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let preparation = try? container.decode(OrderPaymentPreparation.self) {
            self = .preparation(preparation)
        } else if let received = try? container.decode(OrderPaymentReceived.self) {
            self = .received(received)
        } else if let refunded = try? container.decode(OrderPaymentRefunded.self) {
            self = .refunded(refunded)
        } else {
            self = .none
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .preparation(let preparation):
            try container.encode(preparation)
        case .received(let received):
            try container.encode(received)
        case .refunded(let refunded):
            try container.encode(refunded)
        case .none:
            try container.encodeNil()
        }
    }
}
