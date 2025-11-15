public protocol CommonPaymentInput: Codable, Sendable {
    var receiptEmail: String? { get set }
}
