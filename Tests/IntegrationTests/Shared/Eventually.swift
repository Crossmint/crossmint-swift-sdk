import Foundation

enum Eventually {
    /// Polls `read` until it returns a value, for calls whose effect lands on chain after the API answers.
    static func value<T>(
        timeout: TimeInterval = 90,
        describing what: String,
        _ read: () async throws -> T?
    ) async throws -> T {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let found = try await read() { return found }
            try await Task.sleep(nanoseconds: 3_000_000_000)
        }
        throw IntegrationSetupError(message: "\(what) did not happen within \(Int(timeout)) s")
    }
}
