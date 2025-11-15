import SwiftUI
import CrossmintClient

@main
struct SolanaDemoApp: App {
    var body: some Scene {
        WindowGroup {
            SplashScreen()
                .crossmintEnvironmentObject(
                    CrossmintSDK.shared(apiKey: "ck_staging_YOUR_API_KEY")
                ) {
                    OTPValidatorView(nonCustodialSignerCallback: $0)
                }
        }
    }
}
