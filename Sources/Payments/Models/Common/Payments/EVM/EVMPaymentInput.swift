import CrossmintCommonTypes

public struct EVMPaymentInput: CommonPaymentInput {
    public var receiptEmail: String?
    public var method: EVMChain
    public var currency: EVMPaymentInputCurrency
    public var payerAddress: EVMAddress?
}
