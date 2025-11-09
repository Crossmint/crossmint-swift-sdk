public enum CheckoutComPaymentSourceType: String, Encodable, Sendable {
    case token
}

public struct CheckoutComTokenSourceType: Encodable, Sendable {
    public let type: CheckoutComPaymentSourceType = .token
    public let token: String

    public init(token: String) {
        self.token = token
    }
}

public enum CheckoutComPaymentSource: Encodable, Sendable {
    case tokenSource(CheckoutComTokenSourceType)

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .tokenSource(let tokenSource):
            try tokenSource.encode(to: encoder)
        }
    }
}

public enum CheckoutComPaymentType: String, Encodable, Sendable {
    case regular = "Regular"
    case recurring = "Recurring"
    case moto = "MOTO"
    case installment = "Installment"
    case payLater = "PayLater"
    case unscheduled = "Unscheduled"
}

public struct CheckoutComPaymentInput: Encodable, Sendable {
    public let source: CheckoutComPaymentSource
    public let currency: String
    public let amount: Int?
    public let processingChannelId: String?  // Might not be required
    public let reference: String?  // use orderId
    public let metadata: [String: String]?
    public let paymentType: CheckoutComPaymentType?

    public init(
        source: CheckoutComPaymentSource,
        currency: String,
        amount: Int? = nil,
        reference: String? = nil,
        processingChannelId: String? = nil,
        metadata: [String: String]? = nil,
        headlessCheckoutPaymentModality: HeadlessCheckoutPaymentModality? = nil
    ) {
        self.source = source
        self.amount = amount
        self.currency = currency
        self.processingChannelId = processingChannelId
        self.reference = reference
        self.metadata = metadata

        if let headlessCheckoutPaymentModality {
            switch headlessCheckoutPaymentModality {
            case .oneOff:
                self.paymentType = .regular
            case .subscription:
                // TODO might need more fields for recurring payments
                self.paymentType = .recurring
            }
        } else {
            self.paymentType = nil
        }
    }
}
