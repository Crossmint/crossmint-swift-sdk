import CrossmintCommonTypes

public struct CheckoutcomPaymentInput: CommonPaymentInput {
    public var receiptEmail: String?
    public var method: CheckoutComFiatPaymentMethod
    public var currency: FiatCurrency = .usd

    public init(
        receiptEmail: String?, method: CheckoutComFiatPaymentMethod, currency: FiatCurrency = .usd
    ) {
        self.receiptEmail = receiptEmail
        self.method = method
        self.currency = currency
    }
}
