public enum TransactionStatusApiModel: String, Decodable, Sendable {
    case pending
    case success
    case awaitingApproval = "awaiting-approval"
    case failed

    var toDomain: Transaction.Status {
        switch self {
        case .pending:
            return .pending
        case .success:
            return .success
        case .awaitingApproval:
            return .awaitingApproval
        case .failed:
            return .failed
        }
    }
}
