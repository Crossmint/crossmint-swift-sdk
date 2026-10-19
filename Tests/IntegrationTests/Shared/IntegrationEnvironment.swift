import CrossmintAuth
import CrossmintCommonTypes
import CrossmintService
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
    static let appIdentifier = "com.crossmint.integration-tests"
    static let chain = Chain("base-sepolia")
    static let tokenLocator = "base-sepolia:usdxm"

    static func clientApiKey() throws -> ApiKey {
        guard let raw = ProcessInfo.processInfo.environment["PREVIEW_CK_KEY"], !raw.isEmpty else {
            throw IntegrationSetupError(
                message: "PREVIEW_CK_KEY is not set. The integration suite needs a real client key; it does not skip."
            )
        }
        let apiKey = try ApiKey(key: raw)
        guard apiKey.type == .client else {
            throw IntegrationSetupError(
                message: "PREVIEW_CK_KEY must be a client key (ck_); the SDK addresses wallets as `me`."
            )
        }
        return apiKey
    }

    static func service() throws -> DefaultCrossmintService {
        DefaultCrossmintService(apiKey: try clientApiKey(), appIdentifier: appIdentifier)
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
