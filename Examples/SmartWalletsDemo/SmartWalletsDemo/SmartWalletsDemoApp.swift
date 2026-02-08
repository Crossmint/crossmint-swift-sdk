import SwiftUI
import CrossmintClient

@main
struct SmartWalletsDemoApp: App {
    init() {
        CrossmintSDK.configure(with: Configuration(
            apiKey: crossmintApiKey,
            authManager: crossmintAuthManager
        ))
    }

    var body: some Scene {
        WindowGroup {
            SplashScreen()
                .crossmintNonCustodialSigner(CrossmintSDK.shared)
        }
    }
}
