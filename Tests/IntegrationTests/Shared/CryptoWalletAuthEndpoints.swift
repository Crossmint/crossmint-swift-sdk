import Foundation
import Http

enum CryptoWalletAuthEndpoints {
    private static let VERSION = "2024-09-26"
    private static var base: String { "/\(VERSION)/session/sdk/auth/crypto_wallets" }

    /// The SDK's own refresh decoder requires `user.email`, which a wallet-login user does not have.
    static func refresh(oneTimeSecret: String) throws -> Endpoint {
        Endpoint(
            path: "/\(VERSION)/session/sdk/auth/refresh",
            method: .post,
            body: try JSONEncoder().encode(["refresh": oneTimeSecret])
        )
    }

    static func start(walletAddress: String) throws -> Endpoint {
        Endpoint(
            path: "\(base)/authenticate/start",
            method: .post,
            body: try JSONEncoder().encode(["walletAddress": walletAddress, "walletType": "ethereum"])
        )
    }

    static func authenticate(walletAddress: String, challenge: String, signature: String) throws -> Endpoint {
        Endpoint(
            path: "\(base)/authenticate",
            method: .post,
            queryItems: [
                URLQueryItem(name: "signinAuthenticationMethod", value: "evm"),
                URLQueryItem(name: "callbackUrl", value: "https://localhost/sdk/auth/callback")
            ],
            body: try JSONEncoder().encode([
                "walletAddress": walletAddress, "message": challenge, "signature": signature
            ])
        )
    }
}
