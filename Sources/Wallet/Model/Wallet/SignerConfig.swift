import Foundation

/// Identifies a signing key that can be attached to a wallet.
///
/// Pass a `SignerConfig` to ``Wallet/useSigner(_:)``, ``Wallet/addSigner(_:)``, or
/// ``Wallet/recover()`` to configure how the wallet signs transactions on this device.
public enum SignerConfig {
    /// A hardware-backed P-256 key stored in the Secure Enclave (or a Keychain fallback
    /// when Secure Enclave is unavailable). The SDK generates and manages the key automatically.
    case device

    /// An email address registered as a delegated signer.
    case email(String)

    /// A phone number registered as a delegated signer.
    case phone(String)

    /// An external wallet address (EVM, Solana, or Stellar) registered as a delegated signer.
    case externalWallet(address: String)
}
