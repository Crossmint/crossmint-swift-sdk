public struct HeadlessCheckoutCreateOrderInput: Codable, Sendable {
    public var recipient: RecipientInput?
    public var locale: Locale?
    public var payment: PaymentInput
    public var lineItems: CreateOrderLineItems

    public init(
        recipient: RecipientInput?, locale: Locale?, payment: PaymentInput,
        lineItems: CreateOrderLineItems
    ) {
        self.recipient = recipient
        self.locale = locale
        self.payment = payment
        self.lineItems = lineItems
    }
}

public struct HeadlessCheckoutUpdateOrderInput: Codable, Sendable {
    public var recipient: RecipientInput?
    public var locale: Locale?
    public var payment: PaymentInput?

    public init(
        recipient: RecipientInput?, locale: Locale?, payment: PaymentInput?
    ) {
        self.recipient = recipient
        self.locale = locale
        self.payment = payment
    }
}
