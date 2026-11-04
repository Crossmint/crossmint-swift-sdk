import CrossmintService

/// Signs for the offramp with your wallet: the deposit, and the wallet ownership proof when your wallet can sign
/// messages.
///
/// Keep ``CrossmintEmbeddedOfframp`` on screen while the payer runs. Once the view is gone, the page never gets the
/// reply.
public struct EmbeddedOfframpPayer {
    let signAndSendTransaction: @MainActor (OfframpTransaction) async throws -> String
    let signMessage: (@MainActor (OfframpMessage) async throws -> String)?

    /// Creates a payer.
    ///
    /// - Parameters:
    ///   - signAndSendTransaction: Signs and broadcasts the transaction for `payerAddress` on `chain`, unchanged,
    ///     then returns the on-chain transaction hash, or the signature on Solana. Refuse when your wallet is not
    ///     that payer. Throw ``OfframpSignatureRejectedError`` only when the user declined.
    ///   - signMessage: Signs `message` as `payerAddress` on `chain` and returns the signature: the EIP-191
    ///     `personal_sign` hex string, 0x-prefixed, on EVM chains, or the base64 (not base58) encoding of the 64-byte
    ///     ed25519 signature over the UTF-8 message on Solana. The offramp asks only when the user must prove that
    ///     they own the wallet. Refuse when your wallet is not that payer. Throw ``OfframpSignatureRejectedError``
    ///     only when the user declined. Without it, a user who needs the proof is told to verify the wallet in your
    ///     app first. Adding or removing it reloads the offramp.
    public init(
        signAndSendTransaction: @escaping @MainActor (OfframpTransaction) async throws -> String,
        signMessage: (@MainActor (OfframpMessage) async throws -> String)? = nil
    ) {
        self.signAndSendTransaction = signAndSendTransaction
        self.signMessage = signMessage
    }
}

/// The deposit that the offramp asks the payer to sign and send.
public struct OfframpTransaction: Decodable, Sendable {
    public let serializedTransaction: String
    /// The chain of the transaction, for example `base-sepolia` or `solana`.
    public let chain: String
    /// The wallet that must send the transaction.
    public let payerAddress: String
}

/// The wallet ownership proof that the offramp asks the payer to sign: a Crossmint sign-in challenge for
/// `payerAddress`.
public struct OfframpMessage: Decodable, Sendable {
    public let message: String
    public let chain: String
    /// The wallet that must sign the message.
    public let payerAddress: String
}

/// Throw it from the payer when the user declined and the wallet sent nothing.
///
/// The offramp then reports ``OfframpError/Reason/walletRejected`` and lets the user confirm again.
/// Any other error is an unknown outcome, so the offramp waits for the deposit instead of letting the user send it
/// twice.
public struct OfframpSignatureRejectedError: CrossmintError {
    public let code = "OFFRAMP_SIGNATURE_REJECTED"
    public let message: String

    public init(message: String = "The user declined in the wallet") {
        self.message = message
    }
}
