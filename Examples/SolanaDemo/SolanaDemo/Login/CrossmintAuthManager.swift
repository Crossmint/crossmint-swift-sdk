//
//  Crossmint.swift
//  SolanaDemo
//
//  Created by Austin Feight on 11/24/25.
//

import Auth
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
        return "eyJhbGciOiJSUzI1NiIsImtpZCI6Ijk1MTg5MTkxMTA3NjA1NDM0NGUxNWUyNTY0MjViYjQyNWVlYjNhNWMiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL3NlY3VyZXRva2VuLmdvb2dsZS5jb20vb25ld2FsbGV0LTkiLCJhdWQiOiJvbmV3YWxsZXQtOSIsImF1dGhfdGltZSI6MTc2NTA1MjYyOCwidXNlcl9pZCI6IjQzNnVaYWo3cTBaVjRHazRRZThiMll6YkVEVzIiLCJzdWIiOiI0MzZ1WmFqN3EwWlY0R2s0UWU4YjJZemJFRFcyIiwiaWF0IjoxNzY1MDUyNjI4LCJleHAiOjE3NjUwNTYyMjgsImVtYWlsIjoiYXVzdGluQHBhZWxsYS5kZXYiLCJlbWFpbF92ZXJpZmllZCI6ZmFsc2UsImZpcmViYXNlIjp7ImlkZW50aXRpZXMiOnsiZW1haWwiOlsiYXVzdGluQHBhZWxsYS5kZXYiXX0sInNpZ25faW5fcHJvdmlkZXIiOiJwYXNzd29yZCJ9fQ.tSnqghNoDNWtCTFwkWZwOVVoMerGAsDTvoGvwfciG4dhP1Nv0nH1ZYRdX9pgv0YNiuQb4jbbY3tUWbSm5kJohE9Xo82d7P82AKB6KYhSDTMb4SJkTIPrP-FGkV3chh1XXuUz1j1xif_JkG_QoskE22k9c1hK20wkB6JxzsHJIUcfIcyJMP4ROGd7RwwWswfI_3vHekcOMQq-7X0ggupLfa2fmlYPbMNL6HUtTgSpkQlKhXvdZRVtwT51bjo3vIvvMnxC-FSB4SWBd7gEpYYBiW1EePf1yX0GyXxIPR4ij9T-TWgwRTg7x0a5vQkjHHpu6hZRSJbNJpJZCTGbqbACzg"
    }

    // AuthManager requires async get and async setter. Provide a no-op setter here.
    func setJWT(_ jwt: String) async {
        // Implement storing the JWT if needed.
    }
}
