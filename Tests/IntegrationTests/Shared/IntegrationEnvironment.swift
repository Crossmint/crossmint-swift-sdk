import CrossmintAuth
import CrossmintCommonTypes
@testable import CrossmintService
import Foundation
import SecureStorage

struct IntegrationSetupError: CrossmintError {
    let code = "INTEGRATION_SETUP"
    let message: String
    var recoverySuggestion: String? {
        "Set PREVIEW_CK_KEY (a ck_staging_ client key) in the test process environment; "
            + "CI passes it as TEST_RUNNER_PREVIEW_CK_KEY."
    }
}

enum IntegrationEnvironment {
    static let APP_IDENTIFIER = "com.crossmint.integration-tests"
    static let KEY_VARIABLE = "PREVIEW_CK_KEY"
    static let EVM_CHAIN = Chain("base-sepolia")
    static let SOLANA_CHAIN = Chain("solana")
    static let EVM_USDXM = "base-sepolia:usdxm"

    static func clientApiKey(
        from environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> ApiKey {
        guard let raw = environment[KEY_VARIABLE], !raw.isEmpty else {
            throw IntegrationSetupError(
                message: "\(KEY_VARIABLE) is not set. The integration suite needs a real client key; it does not skip."
            )
        }
        let apiKey = try ApiKey(key: raw)
        guard apiKey.type == .client else {
            throw IntegrationSetupError(
                message: "\(KEY_VARIABLE) must be a client key (ck_); the SDK addresses wallets as `me`."
            )
        }
        return apiKey
    }

    static let PREVIEW_BASE_URL_VARIABLE = "PREVIEW_BASE_URL"
    static let PREVIEW_BASE_URL = "https://preview.crossmint.com/api"

    /// A `development` key belongs to preview, which the SDK cannot derive from the key alone.
    static func baseURL(
        for apiKey: ApiKey,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        if let configured = environment[PREVIEW_BASE_URL_VARIABLE], let url = URL(string: configured) {
            return url
        }
        return apiKey.environment == .development ? URL(string: PREVIEW_BASE_URL) : nil
    }

    static func service() throws -> DefaultCrossmintService {
        let apiKey = try clientApiKey()
        return DefaultCrossmintService(
            apiKey: apiKey,
            appIdentifier: APP_IDENTIFIER,
            requestBuilder: DefaultRequestBuilder(baseURL: baseURL(for: apiKey))
        )
    }
}

final class InMemorySecureStorage: SecureStorage, @unchecked Sendable {
    private var values: [String: String] = [:]

    func getOneTimeSecret() async throws(SecureStorageError) -> String? { values["secret"] }
    func storeOneTimeSecret(_ secret: String) async throws(SecureStorageError) { values["secret"] = secret }
    func getJWT() async throws(SecureStorageError) -> String? { values["jwt"] }
    func storeJWT(_ secret: String) async throws(SecureStorageError) { values["jwt"] = secret }
    func getEmail() async throws(SecureStorageError) -> String? { values["email"] }
    func storeEmail(_ email: String) async throws(SecureStorageError) { values["email"] = email }
    func clear() { values.removeAll() }
}

final class InMemorySecureWalletStorage: SecureWalletStorage, @unchecked Sendable {
    private var keys: [String: String] = [:]

    func savePrivateKey(_ privateKey: String, forEmail email: String) { keys[email] = privateKey }
    func getPrivateKey(forEmail email: String) -> String? { keys[email] }
}
