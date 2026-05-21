import Logger

public struct Configuration: Sendable {
    public let apiKey: String
    public let logLevel: LogLevel

    public init(apiKey: String, logLevel: LogLevel = .error) {
        self.apiKey = apiKey
        self.logLevel = logLevel
    }
}
