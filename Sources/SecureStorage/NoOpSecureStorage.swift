import Logger

public struct NoOpSecureStorage: SecureStorage {
    public init() {
        Logger.secureStorage.warn("Secure storage won't be functional. Using non-operational implementation")
    }

    public func getOneTimeSecret() async throws(SecureStorageError) -> String? {
        nil
    }

    public func storeOneTimeSecret(_ secret: String) async throws(SecureStorageError) {
    }

    public func getJWT() async throws(SecureStorageError) -> String? {
        nil
    }

    public func storeJWT(_ secret: String) async throws(SecureStorageError) {
    }

    public func getEmail() async throws(SecureStorageError) -> String? {
        nil
    }

    public func storeEmail(_ email: String) async throws(SecureStorageError) {
    }

    public func savePrivateKey(_ privateKey: String, forEmail email: String) {
    }

    public func getPrivateKey(forEmail email: String) -> String? {
        nil
    }

    public func clear() {
    }
}
