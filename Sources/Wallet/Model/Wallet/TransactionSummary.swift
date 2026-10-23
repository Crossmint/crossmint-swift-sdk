import Foundation

/// A compact result of a transaction that you send.
///
/// Returned by ``Wallet/send(_:_:_:idempotencyKey:signer:prepareOnly:)``.
public struct TransactionSummary: Sendable {
    /// The on-chain transaction hash. The value is `nil` while the status is
    /// ``TransactionStatus/awaitingApproval``.
    public let hash: String?
    /// The Crossmint transaction ID.
    public let transactionID: String
    /// A block explorer URL for this transaction. The value is `nil` while the status is
    /// ``TransactionStatus/awaitingApproval``.
    public let explorerLink: URL?
    /// ``TransactionStatus/success`` when the transaction is on-chain. ``TransactionStatus/awaitingApproval``
    /// when you create it with `prepareOnly`, or when other quorum members must still approve it.
    public let status: TransactionStatus
}
