import Security
import Foundation

public final class KeychainSecureWalletStorage: SecureWalletStorage {
    private let privateKeyStorage: String

    public init(bundleId: String) {
        privateKeyStorage = bundleId + "_privatekeys"
    }

    public func savePrivateKey(_ privateKey: String, forEmail email: String) {
        guard let data = privateKey.data(using: .utf8) else { return }

        let queryDelete: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: email,
            kSecAttrService as String: privateKeyStorage
        ]
        SecItemDelete(queryDelete as CFDictionary)

        let queryAdd: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: email,
            kSecValueData as String: data,
            kSecAttrService as String: privateKeyStorage
        ]

        _ = SecItemAdd(queryAdd as CFDictionary, nil)
    }

    public func getPrivateKey(forEmail email: String) -> String? {
        let queryGet: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: email,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrService as String: privateKeyStorage
        ]

        var item: AnyObject?
        let status = SecItemCopyMatching(queryGet as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let hash = String(data: data, encoding: .utf8) else {
            return nil
        }

        return hash
    }
}
