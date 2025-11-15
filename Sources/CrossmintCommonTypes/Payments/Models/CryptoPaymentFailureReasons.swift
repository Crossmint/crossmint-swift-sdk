public enum CryptoPaymentFailureCode: String, Codable, Sendable {
    case unknown = "unknown"
    case txIdNotFound = "tx-id-not-found"
    case insufficientFunds = "insufficient-funds"
}
