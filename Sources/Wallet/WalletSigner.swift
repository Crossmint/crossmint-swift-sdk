import Web

/// Identifies the signer used to recover and administer a wallet.
public struct WalletSigner: Sendable {
    enum Config: Sendable {
        case email(String, onAuthRequired: @MainActor (OTPFlow) async -> Void)
        case passkey(name: String, host: String)
        case apiKey
    }

    let config: Config

    /// Creates an email-based admin signer. The `onAuthRequired` closure is called when the wallet needs OTP authentication.
    public static func email(
        _ email: String,
        onAuthRequired: @escaping @MainActor (OTPFlow) async -> Void
    ) -> WalletSigner {
        WalletSigner(config: .email(email, onAuthRequired: onAuthRequired))
    }

    /// Creates a passkey-based admin signer.
    public static func passkey(name: String, host: String) -> WalletSigner {
        WalletSigner(config: .passkey(name: name, host: host))
    }

    /// Creates an API key signer.
    public static func apiKey() -> WalletSigner {
        WalletSigner(config: .apiKey)
    }
}
