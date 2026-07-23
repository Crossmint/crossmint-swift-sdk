/// A signer registered on a wallet, as returned by ``Wallet/signers()``.
public struct WalletSigner: Sendable, Hashable {
    /// The signer locator, e.g. `"email:user@example.com"`, `"device:<pubkey>"`,
    /// `"external-wallet:<address>"`, `"passkey:<id>"`.
    public let locator: String

    /// The registration status of this signer on the wallet's chain.
    public let status: SignerStatus
}

/// The registration status of a signer on a wallet.
public enum SignerStatus: String, Sendable, Hashable {
    /// The signer is registered and ready to use.
    case success
    /// The signer is registered and active.
    case active
    /// The registration transaction is still being processed.
    case pending
    /// The registration is waiting for approval from an existing signer.
    case awaitingApproval = "awaiting-approval"
    /// The registration failed.
    case failed
}
