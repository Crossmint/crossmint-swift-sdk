public enum TransactionStatus: String, Sendable {
    case pending
    case awaitingApproval = "awaiting-approval"
    case success
    case failed
}
