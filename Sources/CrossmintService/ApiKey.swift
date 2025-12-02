public enum CrossmintEnvironment: String, Sendable {
    case development
    case staging
    case production
}

enum ApiKeyUsageOriginPrefix: String, CaseIterable {
    case client = "ck"
    case server = "sk"
}

enum ApiKeyEnvironmentPrefix: String, CaseIterable {
    case development
    case staging
    case production
}

public struct ApiKey: Sendable {
    public enum `Type`: Sendable {
        case client
        case server
    }

    public enum Error: Swift.Error, Equatable {
        case oldKey
        case invalidEnviromentKey
        case malformedKey(String)
    }

    public let key: String
    public let type: `Type`
    public let environment: CrossmintEnvironment

    public init(key: String) throws(ApiKey.Error) {
        guard !ApiKey.isOldAPIKey(key: key) else {
            throw ApiKey.Error.oldKey
        }

        let origin = ApiKey.getUsageOrigin(forKey: key)
        guard origin != nil else {
            throw ApiKey.Error.malformedKey(
                // swiftlint:disable:next line_length
                "Malformed API key. Must starts with \(ApiKeyUsageOriginPrefix.client.rawValue) or \(ApiKeyUsageOriginPrefix.server.rawValue)"
            )
        }

        type = origin == .client ? .client : .server

        guard let environmentPrefix = ApiKey.getEnvironment(forKey: key),
              let environment = CrossmintEnvironment(rawValue: environmentPrefix.rawValue) else {
            throw ApiKey.Error.invalidEnviromentKey
        }

        self.key = key
        self.environment = environment
    }

    public var apiEnvironmentPathComponent: String {
        switch environment {
        case .development, .staging:
            "\(environment.rawValue)."
        case .production:
            "www."
        }
    }

    private static func isOldAPIKey(key: String) -> Bool {
        key.starts(with: "sk_live") || key.starts(with: "sk_test")
    }

    private static func getUsageOrigin(forKey key: String) -> ApiKeyUsageOriginPrefix? {
        if key.starts(with: ApiKeyUsageOriginPrefix.client.rawValue + "_") {
            return .client
        } else if key.starts(with: ApiKeyUsageOriginPrefix.server.rawValue + "_") {
            return .server
        } else {
            return nil
        }
    }

    private static func getEnvironment(forKey key: String) -> ApiKeyEnvironmentPrefix? {
        let tokens = key.split(separator: "_")
        return ApiKeyEnvironmentPrefix.allCases.first { prefix in
            prefix.rawValue == tokens[1]
        }
    }

}
