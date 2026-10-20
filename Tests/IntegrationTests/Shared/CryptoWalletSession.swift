import CrossmintAuth
import CrossmintService
import DeviceSigner
import Foundation
@testable import Wallet

/// Logs a fresh user in with a locally generated EVM keypair, the one SDK sign-in that needs no OTP delivery.
struct CryptoWalletSession {
    let service: DefaultCrossmintService
    let authManager: CrossmintAuthManager
    let signer: EVMPersonalSigner
    var address: String { signer.address }

    private struct ChallengeResponse: Decodable {
        let challenge: String
    }

    private struct AuthenticateResponse: Decodable {
        let oneTimeSecret: String
    }

    private struct RefreshResponse: Decodable {
        let jwt: String
    }

    static func start() async throws -> CryptoWalletSession {
        let service = try IntegrationEnvironment.service()
        let authManager = CrossmintAuthManager(
            authService: DefaultAuthService(crossmintService: service),
            secureStorage: InMemorySecureStorage()
        )
        let signer = try await EVMPersonalSigner.make()
        let address = signer.address

        let challenge: ChallengeResponse = try await service.executeRequest(
            try CryptoWalletAuthEndpoints.start(walletAddress: address),
            errorType: AuthError.self
        )
        let signature = try await signer.signText(challenge.challenge)
        let authenticated: AuthenticateResponse = try await service.executeRequest(
            try CryptoWalletAuthEndpoints.authenticate(
                walletAddress: address, challenge: challenge.challenge, signature: signature
            ),
            errorType: AuthError.self
        )
        let refreshed: RefreshResponse = try await service.executeRequest(
            try CryptoWalletAuthEndpoints.refresh(oneTimeSecret: authenticated.oneTimeSecret),
            errorType: AuthError.self
        )
        await authManager.setJWT(refreshed.jwt)
        return CryptoWalletSession(service: service, authManager: authManager, signer: signer)
    }

    func wallets() -> DefaultCrossmintWallets {
        DefaultCrossmintWallets(
            service: DefaultSmartWalletService(crossmintService: service, authManager: authManager),
            secureWalletStorage: InMemorySecureWalletStorage(),
            deviceSignerKeyStorage: KeychainKeyStorage()
        )
    }
}
