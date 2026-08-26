import SwiftUI
import CrossmintClient

@main
struct SmartWalletsDemoApp: App {
    init() {
        CrossmintSDK.configure(apiKey: crossmintApiKey, logLevel: .info, trackingConsent: .granted)
    }

    var body: some Scene {
        WindowGroup {
            SplashScreen()
                .crossmintNonCustodialSigner()
        }
    }
}
