import SwiftUI
import CrossmintClient

@main
struct SmartWalletsDemoApp: App {
    var body: some Scene {
        WindowGroup {
            SplashScreen()
                .crossmintEnvironmentObject(
                    // swiftlint:disable:next line_length
                    CrossmintSDK.shared(apiKey: "ck_staging_2zpUtccNMZRfaeLjf9xfC9SRT6XbHAMPqLEV1fBieAVntqXq97JeWgs7rvy9giGZgGbAucJV8TJh51j71cxfTwczzakVvZc7sGNAujfRE83e2sVLE2KjcNN3qDRDrpvEMNUm8ANu6R13AojfcK5ZDikzTW8B8Mh8PCRG9FcEWWsZGCyoEpSboG2Szi4eJFtPr8bK94KVdT1nXA1J2GyNAYK")
                )
        }
    }
}
