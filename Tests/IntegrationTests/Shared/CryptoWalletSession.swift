import CrossmintAuth
import CrossmintService
import DeviceSigner
import Foundation
import Http
import SwiftKeccak
@testable import Wallet

/// Logs a fresh user in with a locally generated EVM keypair, the one SDK sign-in that needs no OTP delivery.
struct CryptoWalletSession {
    let service: DefaultCrossmintService
    let authManager: CrossmintAuthManager
    let keypair: EVMKeyPairSigner
    let address: String

    private struct ChallengeResponse: Decodable {
        let challenge: String
    }

    private struct AuthenticateResponse: Decodable {
        let oneTimeSecret: String
    }

    static func start() async throws -> CryptoWalletSession {
        let service = try IntegrationEnvironment.service()
        let authManager = CrossmintAuthManager(
            authService: DefaultAuthService(crossmintService: service),
            secureStorage: InMemorySecureStorage()
        )
        let keypair = try EVMKeyPairSigner()
        try await keypair.initialize(nil)
        let address = await keypair.evmAddress.address

        let challenge: ChallengeResponse = try await service.executeRequest(
            Endpoint(
                path: "/2024-09-26/session/sdk/auth/crypto_wallets/authenticate/start",
                method: .post,
                body: try JSONEncoder().encode(["walletAddress": address, "walletType": "ethereum"])
            ),
            errorType: AuthError.self
        )
        let signature = try await keypair.sign(message: Self.personalSignDigest(of: challenge.challenge))
        let authenticated: AuthenticateResponse = try await service.executeRequest(
            Endpoint(
                path: "/2024-09-26/session/sdk/auth/crypto_wallets/authenticate",
                method: .post,
                queryItems: [URLQueryItem(name: "signinAuthenticationMethod", value: "evm")],
                body: try JSONEncoder().encode([
                    "walletAddress": address, "message": challenge.challenge, "signature": signature
                ])
            ),
            errorType: AuthError.self
        )
        _ = try await authManager.oneTimeSecretAuthentication(oneTimeSecret: authenticated.oneTimeSecret)
        return CryptoWalletSession(service: service, authManager: authManager, keypair: keypair, address: address)
    }

    /// EIP-191: keccak256("\u{19}Ethereum Signed Message:\n" + length + message), as hex, which the keypair
    /// signer signs as a digest.
    private static func personalSignDigest(of message: String) -> String {
        let prefixed = Data("\u{19}Ethereum Signed Message:\n\(message.utf8.count)".utf8) + Data(message.utf8)
        return "0x" + keccak256(prefixed).map { String(format: "%02x", $0) }.joined()
    }

    func wallets() -> DefaultCrossmintWallets {
        DefaultCrossmintWallets(
            service: DefaultSmartWalletService(crossmintService: service, authManager: authManager),
            secureWalletStorage: InMemorySecureWalletStorage(),
            deviceSignerKeyStorage: KeychainKeyStorage()
        )
    }
}
