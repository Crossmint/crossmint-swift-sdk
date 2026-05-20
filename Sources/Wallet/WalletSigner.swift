import Web

public struct WalletSigner: Sendable {
    enum Config: Sendable {
        case email(String, onAuthRequired: @Sendable (OTPFlow) async -> Void)
        case passkey(name: String, host: String)
        case apiKey
    }

    let config: Config

    public static func email(
        _ email: String,
        onAuthRequired: @escaping @Sendable (OTPFlow) async -> Void
    ) -> WalletSigner {
        WalletSigner(config: .email(email, onAuthRequired: onAuthRequired))
    }

    public static func passkey(name: String, host: String) -> WalletSigner {
        WalletSigner(config: .passkey(name: name, host: host))
    }

    public static func apiKey() -> WalletSigner {
        WalletSigner(config: .apiKey)
    }
}
