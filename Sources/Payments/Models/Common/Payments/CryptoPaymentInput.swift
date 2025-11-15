public enum CryptoPaymentInput: Codable, Sendable {
    case solanaPaymentInput(SolanaPaymentInput)
    case evmPaymentInput(EVMPaymentInput)
}
