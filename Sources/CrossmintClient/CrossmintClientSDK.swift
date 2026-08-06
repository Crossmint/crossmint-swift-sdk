@_exported import CrossmintAuth
import CrossmintService
import DeviceSigner
import Foundation
import Logger
import SecureStorage
import Wallet

final class CrossmintClientSDK: ClientSDK, Sendable {
    private let apiKey: ApiKey
    private let secureStorage: SecureStorage
    private let secureWalletStorage: SecureWalletStorage
    let crossmintService: CrossmintService
    let authManager: CrossmintAuthManager
    let authClient: any AuthClient

    init(apiKey: ApiKey, authManager: CrossmintAuthManager? = nil) {
        self.apiKey = apiKey

        guard let bundleId = Bundle.main.bundleIdentifier else {
            Logger.sdk.error("Failed to initialize CrossmintClientSDK due to Bundle.main.bundleIdentifier being nil")
            fatalError("Bundle identifier is required for Crossmint SDK to function properly")
        }

        secureStorage = KeychainSecureStorage(bundleId: bundleId)
        secureWalletStorage = KeychainSecureWalletStorage(bundleId: bundleId)
        crossmintService = DefaultCrossmintService(apiKey: apiKey, appIdentifier: bundleId)

        let authService = DefaultAuthService(crossmintService: crossmintService)
        let resolvedAuthManager = authManager
            ?? CrossmintAuthManager(authService: authService, secureStorage: secureStorage)
        self.authManager = resolvedAuthManager
        self.authClient = DefaultAuthClient(authService: authService, authManager: resolvedAuthManager)
    }

    func crossmintWallets() -> CrossmintWallets {
        DefaultCrossmintWallets(
            service: DefaultSmartWalletService(
                crossmintService: crossmintService,
                authManager: authManager
            ),
            secureWalletStorage: secureWalletStorage,
            deviceSignerKeyStorage: DeviceSignerKeyStorageFactory.make()
        )
    }
}
