public enum PaymentInput: Codable, Sendable {
    // TODO uncomment when the integration is ready
    // case stripePaymentInput(StripePaymentInput)
    case checkoutcomPaymentInput(CheckoutcomPaymentInput)
    // case cryptoPaymentInput(CryptoPaymentInput)

    public init(receiptEmail: String?) {
        self = .checkoutcomPaymentInput(
            CheckoutcomPaymentInput(receiptEmail: receiptEmail, method: .checkoutComFlow))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        // case .stripePaymentInput(let paymentInput): try container.encode(paymentInput)
        case .checkoutcomPaymentInput(let paymentInput): try container.encode(paymentInput)
        // case .cryptoPaymentInput(let paymentInput): try container.encode(paymentInput)
        }
    }

    public var receiptEmail: String? {
        switch self {
        case .checkoutcomPaymentInput(let paymentInput): return paymentInput.receiptEmail
        }
    }
}
