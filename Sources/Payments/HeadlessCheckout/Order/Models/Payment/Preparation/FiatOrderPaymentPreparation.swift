public struct StripeOrderPaymentPreparation: Codable, Sendable {
    public var stripeClientSecret: String?
    public var stripePublishableKey: String
    public var stripeEphemeralKeySecret: String?
    public var stripeSubscriptionId: String?
}

public struct CheckoutcomOrderPaymentPreparation: Codable, Sendable {
    public struct CheckoutcomPaymentSession: Codable, Sendable {
        public struct Link: Codable, Sendable {
            public var href: String
        }

        public var id: String
        public var paymentSessionSecret: String
        public var paymentSessionToken: String
        public var links: Links

        public struct Links: Codable, Sendable {
            public let `self`: Link
        }

        enum CodingKeys: String, CodingKey {
            case id
            case paymentSessionSecret = "payment_session_secret"
            case paymentSessionToken = "payment_session_token"
            case links = "_links"
        }
    }

    public var checkoutcomPaymentSession: CheckoutcomPaymentSession?
    public var checkoutcomPublicKey: String
}
