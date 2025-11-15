import Security
import Foundation

public final class KeychainSecureStorage: SecureStorage {
    private enum DataType: String {
        case oneTimeSecret
        case jwtToken
        case email
    }

    private let service: String

    public init(bundleId: String) {
        service = bundleId
    }

    public func getOneTimeSecret() async throws(SecureStorageError) -> String? {
        return try getSecret(for: .oneTimeSecret)
    }

    public func storeOneTimeSecret(_ secret: String) async throws(SecureStorageError) {
        try storeSecret(secret, for: .oneTimeSecret)
    }

    public func getJWT() async throws(SecureStorageError) -> String? {
        return try getSecret(for: .jwtToken)
    }

    public func storeJWT(_ jwt: String) async throws(SecureStorageError) {
        try storeSecret(jwt, for: .jwtToken)
    }

    public func getEmail() async throws(SecureStorageError) -> String? {
        return try getSecret(for: .email)
    }

    public func storeEmail(_ email: String) async throws(SecureStorageError) {
        try storeSecret(email, for: .email)
    }

    private func getSecret(for dataType: DataType) throws(SecureStorageError) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: dataType.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data, let secret = String(data: data, encoding: .utf8) {
            return secret
        } else if status == errSecItemNotFound {
            return nil
        } else {
            throw SecureStorageError.decryptionFailed
        }
    }

    private func storeSecret(_ secret: String, for dataType: DataType) throws(SecureStorageError) {
        guard let secretData = secret.data(using: .utf8) else {
            throw SecureStorageError.encryptionFailed("Failed to convert secret to data")
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: dataType.rawValue,
            kSecValueData as String: secretData
        ]

        SecItemDelete(query as CFDictionary) // Remove old item if it exists
        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            throw SecureStorageError.storageUnavailable
        }
    }

    public func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        SecItemDelete(query as CFDictionary)
    }
}
