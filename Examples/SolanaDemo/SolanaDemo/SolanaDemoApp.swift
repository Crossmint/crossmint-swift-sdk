import SwiftUI
import CrossmintClient

@main
struct SolanaDemoApp: App {
    init() {
        CrossmintSDK.configure(with: Configuration(
            apiKey: crossmintApiKey,
            logLevel: .debug,
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
