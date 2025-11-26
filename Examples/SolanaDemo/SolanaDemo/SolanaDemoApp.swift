import SwiftUI
import CrossmintClient

@main
struct SolanaDemoApp: App {
    var body: some Scene {
        WindowGroup {
            SplashScreen()
                .crossmintNonCustodialSigner(
                    CrossmintSDK.shared(apiKey: crossmintApiKey, authManager: crossmintAuthManager, logLevel: .debug)
                )
        }
    }
}
