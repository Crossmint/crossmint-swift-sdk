//
//  Configuration.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 05/02/26.
//

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

    /// Creates a new configuration instance.
    ///
    /// - Parameters:
    ///   - apiKey: The Crossmint API key (required).
    ///   - logLevel: The logging level. Defaults to `.info`.
    public init(
        apiKey: String,
        logLevel: LogLevel = .info
    ) {
        self.apiKey = apiKey
        self.logLevel = logLevel
    }
}
