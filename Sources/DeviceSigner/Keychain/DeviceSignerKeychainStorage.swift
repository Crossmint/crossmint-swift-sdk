import Foundation
import LocalAuthentication
import Security

private let service = "com.crossmint.devicesigner"

struct DeviceSignerKeychainStorage {
    func save(_ data: Data, tag: String, accessControl: SecAccessControl? = nil) throws(DeviceSignerError) {
        let deleteQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: tag
        ]
        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
            throw DeviceSignerError.storageError(deleteStatus)
        }

        var addQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: tag,
            kSecValueData: data
        ]
        if let accessControl {
            addQuery[kSecAttrAccessControl] = accessControl
        } else {
            addQuery[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw DeviceSignerError.storageError(status)
        }
    }

    func load(tag: String, prompt: String? = nil, authContext: LAContext? = nil) -> Data? {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: tag,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        if let authContext {
            query[kSecUseAuthenticationContext] = authContext
        } else if let prompt {
            let context = LAContext()
            context.localizedReason = prompt
            query[kSecUseAuthenticationContext] = context
        }
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    func rename(from oldTag: String, to newTag: String) throws(DeviceSignerError) {
        // Remove any existing item at the target tag to avoid errSecDuplicateItem (-25299).
        let deleteTarget: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: newTag
        ]
        let deleteStatus = SecItemDelete(deleteTarget as CFDictionary)
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
            throw DeviceSignerError.storageError(deleteStatus)
        }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: oldTag
        ]
        let attributes: [CFString: Any] = [
            kSecAttrAccount: newTag
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else {
            throw DeviceSignerError.storageError(status)
        }
    }

    func delete(tag: String) throws(DeviceSignerError) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: tag
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw DeviceSignerError.storageError(status)
        }
    }
}
