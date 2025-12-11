//
//  Crossmint.swift
//  SolanaDemo
//
//  Created by Austin Feight on 11/24/25.
//

import CrossmintAuth
import CrossmintClient
import os.log

let crossmintApiKey = "ck_staging_5vTwWwHDwCo7R2ddTpgRseTPESbox9ytP2EosFCwPVXUXZkEgCSWBuELN4mMf8fkfCnFZyt4oyEgWbwaytP8KT24Qgrmagpxjj16AYbWGtxzsV9wrrJrLV4GGcrxapMNRdCQ3BtM5U56HpxTMToLTEpc4T65DHvUmrZPBuHtTakGeAtr6JafhX9qNUZawdH9zSsWJ3c5UDWCnHpqpAv9dxCK"

// Initialize the CrossmintAuthManager (actor, non-main) is fine at file scope.
// swiftlint:disable:next force_try
let crossmintAuthManager = try! CrossmintAuthManager(apiKey: crossmintApiKey)

// Provide a single FirebaseAuthManager instance if you still need it elsewhere.
let authManager = FirebaseAuthManager()

// MainActor accessor for the SDK. Call getSDK() from the main actor (e.g., in Views or App lifecycle).

@MainActor
enum CrossmintSDKProvider {
    private static var cached: CrossmintSDK?

    static func getSDK() -> CrossmintSDK {
        if let cached {
            return cached
        }
        let instance = CrossmintSDK.shared(apiKey: crossmintApiKey, authManager: FirebaseAuthManager(), logLevel: .debug)
        cached = instance
        return instance
    }
}

// Example convenience to access the default shared (no params) on main actor if desired.
@MainActor
var sdk: CrossmintSDK {
    CrossmintSDKProvider.getSDK()
}

final class FirebaseAuthManager: AuthManager {
    let email = "austin@paella.dev"

    var jwt: String? {
        return "eyJhbGciOiJSUzI1NiIsImtpZCI6IjM4MTFiMDdmMjhiODQxZjRiNDllNDgyNTg1ZmQ2NmQ1NWUzOGRiNWQiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL3NlY3VyZXRva2VuLmdvb2dsZS5jb20vb25ld2FsbGV0LTkiLCJhdWQiOiJvbmV3YWxsZXQtOSIsImF1dGhfdGltZSI6MTc2NTMyMjk4OCwidXNlcl9pZCI6IjQzNnVaYWo3cTBaVjRHazRRZThiMll6YkVEVzIiLCJzdWIiOiI0MzZ1WmFqN3EwWlY0R2s0UWU4YjJZemJFRFcyIiwiaWF0IjoxNzY1MzIyOTg4LCJleHAiOjE3NjUzMjY1ODgsImVtYWlsIjoiYXVzdGluQHBhZWxsYS5kZXYiLCJlbWFpbF92ZXJpZmllZCI6ZmFsc2UsImZpcmViYXNlIjp7ImlkZW50aXRpZXMiOnsiZW1haWwiOlsiYXVzdGluQHBhZWxsYS5kZXYiXX0sInNpZ25faW5fcHJvdmlkZXIiOiJwYXNzd29yZCJ9fQ.UtJXzbXxcE3xFI00L87vjuoUoSpoKYnUfp1Vwrn5kHKJNmihN0mNlyWwNEEtLMkcqQ1AjLaN-AJJHO_4FOyYi-axxjInh3Ryava0JP8lRZ0t22Ovt_a4auNJ2JfF1Iz9e2QpT4o9Aeuijtq3CFE4BRPOlXyxT842NH85kmc2Dtki49PwJkJyYQiOU2IXwteTy7KFp9M7rmiC-8ss1y26BWvXVc7qJQHjHVcN9OrYw4990y0PzKRtpG9qClxlOQLVMQQQs1bpnqGnxzMEUyJo7_f05mWmITxHA9r6Pi0lq3HNZflQM0Iv0DmCWe_zpMgq0H4IoJDxOBHJKAaKFqpLlA"
    }

    // AuthManager requires async get and async setter. Provide a no-op setter here.
    func setJWT(_ jwt: String) async {
        // Implement storing the JWT if needed.
    }
}
