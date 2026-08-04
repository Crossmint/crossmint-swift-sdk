@_exported @preconcurrency import OSLog
import Utils

public struct Logger: Sendable {

    private let providers: [LoggerProvider]
    public nonisolated(unsafe) static var level: LogLevel = .error

    private let osLogger: OSLog
    private let subsystem: String

    public init(category: String) {
        self.subsystem = "CrossmintSDK"
        self.osLogger = OSLog(subsystem: subsystem, category: category)

        providers = [
            OSLoggerProvider(category: category),
            DataDogLoggerProvider(
                service: category,
                clientToken: DataDogConfig.clientToken,
                environment: DataDogConfig.environment
            )
        ]
    }

    init(testProviders: [LoggerProvider]) {
        self.subsystem = "CrossmintSDK"
        self.osLogger = OSLog(subsystem: subsystem, category: "test")
        self.providers = testProviders
    }

    public func debug(_ message: String, attributes: [String: Encodable]? = nil) {
        forward(message, attributes) { $0.debug($1, attributes: $2) }
    }

    public func error(_ message: String, attributes: [String: Encodable]? = nil) {
        forward(message, attributes) { $0.error($1, attributes: $2) }
    }

    public func info(_ message: String, attributes: [String: Encodable]? = nil) {
        forward(message, attributes) { $0.info($1, attributes: $2) }
    }

    public func warning(_ message: String, attributes: [String: Encodable]? = nil) {
        forward(message, attributes) { $0.warning($1, attributes: $2) }
    }

    /// Every level funnels through here so scrubbing can't be missed when a level is added.
    private func forward(
        _ message: String,
        _ attributes: [String: Encodable]?,
        to log: (LoggerProvider, String, [String: Encodable]?) -> Void
    ) {
        let message = CredentialScrubber.scrub(message)
        let attributes = CredentialScrubber.scrub(attributes)
        for provider in providers {
            log(provider, message, attributes)
        }
    }

    public func flush() async {
        for provider in providers {
            await provider.flush()
        }
    }
}
