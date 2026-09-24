import CrossmintCommonTypes

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
    ///
    /// `channel` selects how the OTP is delivered. It applies to each onboarding request rather
    /// than to the signer, so ``Wallet/addSigner(_:)`` ignores it — the registration endpoint has
    /// no channel field. The signer service delivers by SMS when no channel is given.
    case phone(String, channel: OTPDeliveryChannel? = nil)
    /// An external wallet signer identified by its blockchain address.
    ///
    /// ``Wallet/useSigner(_:)`` requires `onSign`. ``Wallet/addSigner(_:)`` ignores it.
    ///
    /// The SDK calls `onSign` with the approval payload for each pending approval of this signer,
    /// and sends the returned value as the signature. The payload and the signature use the
    /// encoding of the wallet's chain:
    /// - EVM: the payload is a `0x`-prefixed hex string. Sign its raw bytes as an EIP-191
    ///   personal message (`personal_sign`) and return the `0x`-prefixed 65-byte hex signature.
    /// - Solana: the payload is a base58 string. Sign its decoded bytes with Ed25519 and return
    ///   the 64-byte signature as base58.
    /// - Stellar: the payload is a base64 string. Sign its decoded bytes with Ed25519 and return
    ///   the 64-byte signature as base64.
    ///
    /// Throw ``SignerError/cancelled`` from `onSign` when the user declines to sign.
    case externalWallet(String, onSign: (@Sendable (String) async throws -> String)? = nil)
    /// The API key signer (server-side / custodial).
    case apiKey
}

extension SignerConfig {
    /// The locator for this signer config, or `nil` for types whose locator
    /// cannot be determined without async context (`.device`) or server-assigned data (`.passkey`).
    var locator: SignerLocator? {
        switch self {
        case .email(let email): .email(email)
        case .phone(let phone, _): .phone(phone)
        case .externalWallet(let address, _): .externalWallet(address: address)
        case .apiKey: .apiKey()
        case .device, .passkey: nil
        }
    }
}
