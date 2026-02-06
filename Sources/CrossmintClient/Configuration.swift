//
//  Configuration.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 05/02/26.
//

import CrossmintAuth
import Foundation
import Logger

/// Configuration for the Crossmint SDK.
///
/// Example:
/// ```swift
/// CrossmintSDK.configure(with: Configuration(
///     apiKey: "ck_staging_...",
///     logLevel: .debug
/// ))
/// ```
public struct Configuration: Sendable {
    /// The Crossmint API key.
    public let apiKey: String

    /// The logging level for SDK operations. Defaults to `.info`.
    public let logLevel: LogLevel

    /// Optional custom auth manager. If not provided, the SDK creates a default one.
    /// This will be removed in a future version.
    public let authManager: AuthManager?

    /// Creates a new configuration instance.
    ///
    /// - Parameters:
    ///   - apiKey: The Crossmint API key (required).
    ///   - logLevel: The logging level. Defaults to `.info`.
    ///   - authManager: Optional custom auth manager. Defaults to `nil`.
    public init(
        apiKey: String,
        logLevel: LogLevel = .info,
        authManager: AuthManager? = nil
    ) {
        self.apiKey = apiKey
        self.logLevel = logLevel
        self.authManager = authManager
    }
}
