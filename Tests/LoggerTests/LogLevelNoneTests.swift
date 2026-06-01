@testable import Logger
import Testing

// Spy that records whether any log method was invoked.
private final class SpyProvider: LoggerProvider, @unchecked Sendable {
    var calls: [String] = []

    func debug(_ message: String, attributes: [String: Encodable]?) { calls.append("debug") }
    func info(_ message: String, attributes: [String: Encodable]?) { calls.append("info") }
    func warning(_ message: String, attributes: [String: Encodable]?) { calls.append("warning") }
    func error(_ message: String, attributes: [String: Encodable]?) { calls.append("error") }
}

@Suite("LogLevel.none suppresses all output")
struct LogLevelNoneTests {
    @Test("none rawValue is greater than error rawValue")
    func noneRawValueIsAboveError() {
        #expect(LogLevel.none.rawValue > LogLevel.error.rawValue)
    }

    @Test("Logger emits nothing at level .none")
    func loggerSilentAtNone() {
        let saved = Logger.level
        defer { Logger.level = saved }

        Logger.level = .none
        let spy = SpyProvider()
        let logger = Logger(testProviders: [spy])

        logger.debug("d")
        logger.info("i")
        logger.warning("w")
        logger.error("e")

        #expect(spy.calls.isEmpty, "Expected no calls when level is .none, got: \(spy.calls)")
    }

    @Test("Logger emits at level .error")
    func loggerEmitsAtError() {
        let saved = Logger.level
        defer { Logger.level = saved }

        Logger.level = .error
        let spy = SpyProvider()
        let logger = Logger(testProviders: [spy])

        logger.debug("d")
        logger.info("i")
        logger.warning("w")
        logger.error("e")

        #expect(spy.calls == ["error"])
    }
}
