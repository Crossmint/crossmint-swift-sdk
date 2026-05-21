import SwiftUI
import CrossmintClient

@main
struct SmartWalletsDemoApp: App {
    init() {
        CrossmintSDK.configure(apiKey: crossmintApiKey, logLevel: .info)
    }

    var body: some Scene {
        WindowGroup {
            SplashScreen()
                .crossmintNonCustodialSigner()
        }
    }
}
