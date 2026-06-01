import Logger

/// SDK-wide configuration passed to ``CrossmintSDK``.
///
/// Use the simple factory when defaults are acceptable:
/// ```swift
/// CrossmintSDK.configure(apiKey: "ck_staging_...")
/// ```
///
/// Use ``Configuration`` when you need to override defaults:
/// ```swift
/// CrossmintSDK.configure(with: Configuration(
///     apiKey: "ck_staging_...",
///     logLevel: .debug
/// ))
/// ```
public struct Configuration: Sendable {
    /// A client API key (prefixed `ck_`).
    public let apiKey: String

    /// Controls SDK log verbosity. Defaults to `.error`.
    public let logLevel: LogLevel

    /// Creates a configuration value.
    ///
    /// - Parameters:
    ///   - apiKey: A client API key (prefixed `ck_`).
    ///   - logLevel: Controls SDK log verbosity. Defaults to `.error`.
    public init(apiKey: String, logLevel: LogLevel = .error) {
        self.apiKey = apiKey
        self.logLevel = logLevel
    }
}
