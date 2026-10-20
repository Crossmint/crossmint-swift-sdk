import Foundation

/// A compact result returned after a token transfer is confirmed on-chain.
///
/// Returned by ``Wallet/send(_:_:_:idempotencyKey:prepareOnly:)``.
public struct TransactionSummary: Sendable {
    /// The on-chain transaction hash. The value is `nil` when you create the transaction with `prepareOnly`.
    public let hash: String?
    /// The Crossmint transaction ID.
    public let transactionID: String
    /// A block explorer URL for this transaction. The value is `nil` when you create the transaction with `prepareOnly`.
    public let explorerLink: URL?
}
