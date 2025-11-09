import CrossmintCommonTypes

public struct StripePaymentInput: CommonPaymentInput {
    public var receiptEmail: String?
    public var method: StripeFiatPaymentMethod
    public var currency: FiatCurrency = .usd
}
