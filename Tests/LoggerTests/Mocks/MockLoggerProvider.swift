@testable import Logger

final class MockLoggerProvider: LoggerProvider, @unchecked Sendable {
    /// Levels in call order. The per-level counts below derive from this, so a test can assert
    /// either ordering or counts without two sources of truth.
    var calls: [String] = []
    var lastMessage: String?
    var lastAttributes: [String: Encodable]?

    var debugCallCount: Int { calls.filter { $0 == "debug" }.count }
    var infoCallCount: Int { calls.filter { $0 == "info" }.count }
    var warningCallCount: Int { calls.filter { $0 == "warning" }.count }
    var errorCallCount: Int { calls.filter { $0 == "error" }.count }

    func debug(_ message: String, attributes: [String: Encodable]?) {
        record("debug", message, attributes)
    }

    func info(_ message: String, attributes: [String: Encodable]?) {
        record("info", message, attributes)
    }

    func warning(_ message: String, attributes: [String: Encodable]?) {
        record("warning", message, attributes)
    }

    func error(_ message: String, attributes: [String: Encodable]?) {
        record("error", message, attributes)
    }

    private func record(_ level: String, _ message: String, _ attributes: [String: Encodable]?) {
        calls.append(level)
        lastMessage = message
        lastAttributes = attributes
    }
}
