import Foundation

public enum OrderPaymentStatus: String, Codable, Sendable {
    case requiresQuote = "requires-quote"
    case requiresCryptoPayerAddress = "requires-crypto-payer-address"
    case requiresEmail = "requires-email"
    case requiresKyc = "requires-kyc"
    case manualKyc = "manual-kyc"
    case failedKyc = "failed-kyc"
    case cryptoPayerInsufficientFunds = "crypto-payer-insufficient-funds"
    case awaitingPayment = "awaiting-payment"
    case inProgress = "in-progress"
    case completed = "completed"
}
