/// The lifecycle state of a transaction submitted through the Crossmint API.
public enum TransactionStatus: String, Sendable {
    /// Submitted to the API but not yet broadcast to the network.
    case pending
    /// Waiting for one or more signers to approve before it can be submitted.
    case awaitingApproval = "awaiting-approval"
    /// Confirmed on-chain.
    case success
    /// Rejected or reverted on-chain.
    case failed
    /// Crossmint cancelled the transaction before it got all its approvals. The transaction does not run.
    ///
    /// Only a Solana quorum transaction can get this status. Crossmint cancels the transaction
    /// when its ``Transaction/validUntil`` date passes. Crossmint also cancels it when a signer of the wallet changes.
    case cancelled
}
