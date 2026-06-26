@testable import Logger
import Testing

// Simulates a DataDog-like provider that always forwards regardless of Logger.level.
private final class AlwaysOnSpy: LoggerProvider, @unchecked Sendable {
    var calls: [String] = []

    func debug(_ message: String, attributes: [String: Encodable]?) { calls.append("debug") }
    func info(_ message: String, attributes: [String: Encodable]?) { calls.append("info") }
    func warning(_ message: String, attributes: [String: Encodable]?) { calls.append("warning") }
    func error(_ message: String, attributes: [String: Encodable]?) { calls.append("error") }
}

// Simulates an OSLog-like provider that respects Logger.level.
private final class LevelRespectingSpy: LoggerProvider, @unchecked Sendable {
    var calls: [String] = []

    func debug(_ message: String, attributes: [String: Encodable]?) {
        guard Logger.level.rawValue <= LogLevel.debug.rawValue else { return }
        calls.append("debug")
    }
    func info(_ message: String, attributes: [String: Encodable]?) {
        guard Logger.level.rawValue <= LogLevel.info.rawValue else { return }
        calls.append("info")
    }
    func warning(_ message: String, attributes: [String: Encodable]?) {
        guard Logger.level.rawValue <= LogLevel.warning.rawValue else { return }
        calls.append("warning")
    }
    func error(_ message: String, attributes: [String: Encodable]?) {
        guard Logger.level.rawValue <= LogLevel.error.rawValue else { return }
        calls.append("error")
    }
}

// Serialized: all tests mutate the shared Logger.level global and would race in parallel
@Suite("LogLevel filtering", .serialized)
struct LogLevelNoneTests {
    @Test("none rawValue is greater than error rawValue")
    func noneRawValueIsAboveError() {
        #expect(LogLevel.silent.rawValue > LogLevel.error.rawValue)
    }

    @Test("remote providers always receive logs regardless of level")
    func remoteProviderIgnoresLogLevel() {
        let saved = Logger.level
        defer { Logger.level = saved }

        Logger.level = .silent
        let spy = AlwaysOnSpy()
        let logger = Logger(testProviders: [spy])

        logger.debug("d")
        logger.info("i")
        logger.warning("w")
        logger.error("e")

        #expect(spy.calls == ["debug", "info", "warning", "error"])
    }

    @Test("console providers respect Logger.level")
    func consoleProviderRespectsLogLevel() {
        let saved = Logger.level
        defer { Logger.level = saved }

        Logger.level = .error
        let spy = LevelRespectingSpy()
        let logger = Logger(testProviders: [spy])

        logger.debug("d")
        logger.info("i")
        logger.warning("w")
        logger.error("e")

        #expect(spy.calls == ["error"])
    }

    @Test("console providers emit nothing at level .silent")
    func consoleProviderSilentAtNone() {
        let saved = Logger.level
        defer { Logger.level = saved }

        Logger.level = .silent
        let spy = LevelRespectingSpy()
        let logger = Logger(testProviders: [spy])

        logger.debug("d")
        logger.info("i")
        logger.warning("w")
        logger.error("e")

        #expect(spy.calls.isEmpty)
    }
}
