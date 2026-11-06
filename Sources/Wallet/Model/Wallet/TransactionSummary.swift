import Foundation

/// A compact result of a transaction that you send.
///
/// Returned by ``Wallet/send(_:_:_:idempotencyKey:signer:prepareOnly:)``.
public struct TransactionSummary: Sendable {
    /// The on-chain transaction hash. The value is `nil` until the transaction is on-chain.
    public let hash: String?
    /// The Crossmint transaction ID.
    public let transactionID: String
    /// A block explorer URL for this transaction. The value is `nil` until the transaction is on-chain.
    public let explorerLink: URL?
}
