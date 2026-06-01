import Foundation
import Security

// Stores the 32-byte master secret received from the TEE during onboarding.
// Each user/signer combination gets its own Keychain entry keyed by signerID.
//
// The Keychain uses hardware-backed keys (managed by the Secure Enclave) to
// encrypt items stored with kSecAttrAccessibleWhenUnlockedThisDeviceOnly.
// Items cannot be moved to another device or read while locked.
public enum MasterSecretStore {
    private static let service = "com.crossmint.devicesigner.mastersecret"

    public static func save(_ masterSecret: Data, forSignerID signerID: String) throws {
        let delete: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: signerID,
        ]
        SecItemDelete(delete as CFDictionary)

        let add: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: signerID,
            kSecValueData: masterSecret,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw StoreError.saveFailed(status) }
    }

    public static func load(forSignerID signerID: String) -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: signerID,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return data
    }

    public static func exists(forSignerID signerID: String) -> Bool {
        load(forSignerID: signerID) != nil
    }

    public static func delete(forSignerID signerID: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: signerID,
        ]
        SecItemDelete(query as CFDictionary)
    }

    public enum StoreError: Error {
        case saveFailed(OSStatus)
    }
}
