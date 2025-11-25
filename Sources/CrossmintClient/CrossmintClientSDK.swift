@_exported import Auth
import CrossmintService
import Foundation
import Logger
import SecureStorage
import Wallet

public final class CrossmintClientSDK: ClientSDK, Sendable {
    private let apiKey: ApiKey
    private let secureStorage: SecureStorage
    private let secureWalletStorage: SecureWalletStorage
    public let crossmintService: CrossmintService
    public let authManager: any Auth.AuthManager

    init(apiKey: ApiKey, authManager: AuthManager? = nil) {
        self.apiKey = apiKey

        guard let bundleId = Bundle.main.bundleIdentifier else {
            Logger.sdk.error("Bundle identifier is required for Crossmint SDK to function properly")
            fatalError("Bundle identifier is required for Crossmint SDK to function properly")
        }

        secureStorage = KeychainSecureStorage(bundleId: bundleId)
        secureWalletStorage = KeychainSecureWalletStorage(bundleId: bundleId)
        crossmintService = DefaultCrossmintService(apiKey: apiKey, appIdentifier: bundleId)

        if let authManager {
            self.authManager = authManager
        } else {
            self.authManager = CrossmintAuthManager(
                authService: DefaultAuthService(crossmintService: crossmintService),
                secureStorage: secureStorage
            )
        }
    }

    public func crossmintWallets() -> CrossmintWallets {
        DefaultCrossmintWallets(
            service: DefaultSmartWalletService(
                crossmintService: crossmintService,
                authManager: authManager
            ),
            secureWalletStorage: secureWalletStorage
        )
    }
}
