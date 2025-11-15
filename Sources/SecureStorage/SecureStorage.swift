public enum SecureStorageError: Error {
    case unknown
    case decryptionFailed
    case encryptionFailed(String)
    case storageUnavailable
}

public protocol SecureStorage: Sendable {
    func getOneTimeSecret() async throws(SecureStorageError) -> String?
    func storeOneTimeSecret(_ secret: String) async throws(SecureStorageError)

    func getJWT() async throws(SecureStorageError) -> String?
    func storeJWT(_ secret: String) async throws(SecureStorageError)

    func getEmail() async throws(SecureStorageError) -> String?
    func storeEmail(_ email: String) async throws(SecureStorageError)

    func clear()
}
