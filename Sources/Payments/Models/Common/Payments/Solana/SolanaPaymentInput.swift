import CrossmintCommonTypes

public enum SolanaPaymentMethod: String, Codable, Sendable {
    case solana
}

public struct SolanaPaymentInput: CommonPaymentInput {
    public var receiptEmail: String?
    public var method: SolanaPaymentMethod
    public var currency: SolanaPaymentInputCurrency
    public var payerAddress: SolanaAddress?
}
