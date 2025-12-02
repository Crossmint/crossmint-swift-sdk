@_exported @preconcurrency import OSLog
import Utils

public struct Logger: Sendable {

    private nonisolated(unsafe) let providers: [LoggerProvider]
    public nonisolated(unsafe) static var level: OSLogType = .fault

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

    public func debug(_ message: String) {
        guard Logger.level == .debug else { return }
        for provider in providers {
            provider.debug(message, attributes: nil)
        }
    }

    public func error(_ message: String) {
        guard Logger.level != .fault else { return }
        for provider in providers {
            provider.error(message, attributes: nil)
        }
    }

    public func info(_ message: String) {
        guard [.debug, .info].contains(Logger.level) else { return }
        for provider in providers {
            provider.info(message, attributes: nil)
        }
    }

    public func warn(_ message: String) {
        guard [.debug, .info, .default].contains(Logger.level) else { return }
        for provider in providers {
            provider.warn(message, attributes: nil)
        }
    }
}
