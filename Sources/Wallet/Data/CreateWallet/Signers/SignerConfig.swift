/// Describes which signer to use for wallet operations.
///
/// Pass a `SignerConfig` to ``Wallet/useSigner(_:)`` to set the active signer,
/// or to ``Wallet/addSigner(_:)`` to register a new signer on the wallet.
///
/// - Note: `.passkey` is only supported on EVM chains.
public enum SignerConfig: Sendable {
    /// The device's Secure Enclave (or software fallback) as the signer.
    /// Created lazily on first transaction if no local key exists.
    case device
    /// A passkey credential. EVM only.
    case passkey(name: String, host: String)
    /// An email OTP signer.
    case email(String)
    /// A phone OTP signer. The phone number must be in E.164 format (e.g. `"+15551234567"`).
    case phone(String)
    /// An external wallet signer identified by its blockchain address.
    case externalWallet(String)
    /// The API key signer (server-side / custodial).
    case apiKey
}

extension SignerConfig {
    /// The locator for this signer config, or `nil` for types whose locator
    /// cannot be determined without async context (`.device`) or server-assigned data (`.passkey`).
    var locator: SignerLocator? {
        switch self {
        case .email(let email): .email(email)
        case .phone(let phone): .phone(phone)
        case .externalWallet(let address): .externalWallet(address: address)
        case .apiKey: .apiKey()
        case .device, .passkey: nil
        }
    }
}
