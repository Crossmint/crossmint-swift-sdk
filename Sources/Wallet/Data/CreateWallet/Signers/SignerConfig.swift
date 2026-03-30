import DeviceSigner

/// Describes which signer to use for wallet operations.
///
/// Pass a `SignerConfig` to ``Wallet/useSigner(_:)`` to set the active signer,
/// or to ``Wallet/addSigner(_:)`` to register a new signer on the wallet.
///
/// - Note: `.passkey` is only supported on EVM chains.
public enum SignerConfig: Sendable {
    /// The device's Secure Enclave (or software fallback) as the signer.
    /// Created lazily on first transaction if no local key exists.
    case device(DeviceSignerOptions)
    /// A passkey credential. EVM only.
    case passkey(name: String, host: String)
    /// An email OTP signer.
    case email(String)
    /// The API key signer (server-side / custodial).
    case apiKey
}
