import Testing
@testable import CrossmintService

struct ApiKeyTest {
    @Test(
        "Will throw for every environment when the API key is old",
        arguments: ["sk_live", "sk_test"]
    )
    func willThrowWhenTheApiKeyIsOld(key: String) async throws {
        #expect(throws: ApiKey.Error.oldKey) {
            try ApiKey(key: key)
        }
    }

    @Test(
        "Will throw if the API key does not start with the correct prefix",
        arguments: ApiKeyUsageOriginPrefix.allCases
    )
    func willThrowIfTheApiKeyDoesNotStartWithTheCorrectPrefix(prefix: ApiKeyUsageOriginPrefix) async throws {
        let expectedError = ApiKey.Error.malformedKey(
            // swiftlint:disable:next line_length
            "Malformed API key. Must starts with \(ApiKeyUsageOriginPrefix.client.rawValue) or \(ApiKeyUsageOriginPrefix.server.rawValue)"
        )
        let invalidPrefix = prefix.rawValue.dropFirst()
        #expect(throws: expectedError) {
            try ApiKey(key: invalidPrefix + "_")
        }
    }

    @Test(
        "Will extract the expected environment from the API key",
        arguments: ApiKeyEnvironmentPrefix.allCases
    )
    func willExtractTheExpectedEnvironmentFromTheApiKey(prefix: ApiKeyEnvironmentPrefix) async throws {
        let key = "\(ApiKeyUsageOriginPrefix.client.rawValue)_\(prefix.rawValue)"
        let apiKey = try ApiKey(key: key)
        #expect(apiKey.environment == prefix.expectedEnvironment)
    }
}

private extension ApiKeyEnvironmentPrefix {
    var expectedEnvironment: CrossmintEnvironment {
        return switch self {
        case .development:
                .development
        case .staging:
                .staging
        case .production:
                .production
        }
    }
}
