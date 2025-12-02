//
//  DataDogConfig.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 2/12/25.
//

import Foundation

public enum DataDogConfig {
    /// Crossmint's DataDog client token for iOS SDK logging
    /// This is a public client token, safe to embed in the SDK
    static let clientToken = "pub946d87ea0c2cc02431c15e9446f776fc"

    /// Current environment - defaults to production, updated during SDK initialization
    private nonisolated(unsafe) static var _environment: String = "production"

    /// Get the current environment
    static var environment: String {
        _environment
    }

    /// Configure the environment (called during SDK initialization with API key)
    public static func configure(environment: String) {
        _environment = environment
    }
}
