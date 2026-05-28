import Foundation

public struct TransactionResult: Sendable {
    public let transactionId: String
    // nil when the tx is a user-op bundled into a meta-transaction (hash lives in userOperationHash instead)
    public let hash: String?
    public let explorerLink: URL?
}
