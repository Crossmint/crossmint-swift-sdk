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
    /// A signer that uses an external wallet. The first value is the address of the wallet.
    ///
    /// To use this signer with ``Wallet/useSigner(_:)``, you must set `onSign`.
    /// ``Wallet/addSigner(_:)`` does not use `onSign`.
    ///
    /// The SDK calls `onSign` each time the wallet needs an approval from this signer.
    /// `onSign` receives a message. Sign the message with the external wallet and return the signature.
    /// The format of the message and of the signature changes with the chain of the wallet:
    /// - EVM: The message is a hex string that starts with `0x`. Decode the hex string.
    ///   Sign the bytes as an EIP-191 personal message (`personal_sign`).
    ///   Return the 65-byte signature as a hex string that starts with `0x`.
    /// - Solana: The message is a base58 string. Decode the string and sign the bytes with Ed25519.
    ///   Return the 64-byte signature as a base58 string.
    /// - Stellar: The message is a base64 string. Decode the string and sign the bytes with Ed25519.
    ///   Return the 64-byte signature as a base64 string.
    ///
    /// If the user does not accept the request to sign, throw ``SignerError/cancelled`` from `onSign`.
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
