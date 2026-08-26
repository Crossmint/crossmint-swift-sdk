import Foundation

/// A compact result returned after a token transfer is confirmed on-chain.
///
/// Returned by ``Wallet/send(_:_:_:idempotencyKey:)``.
public struct TransactionSummary: Sendable {
    /// The on-chain transaction hash.
    public let hash: String
    /// The Crossmint transaction ID.
    public let transactionID: String
    /// A block explorer URL for this transaction.
    public let explorerLink: URL
}
