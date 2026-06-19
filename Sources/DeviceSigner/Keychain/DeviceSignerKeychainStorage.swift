import Foundation
import LocalAuthentication
import OSLog
import Security

private let logger = Logger(subsystem: "com.crossmint.devicesigner", category: "KeychainStorage")

protocol KeychainItemStore: Sendable {
    func save(_ data: Data, tag: String, accessControl: SecAccessControl?) throws(DeviceSignerError)
    func load(tag: String, prompt: String?, authContext: LAContext?) -> Data?
    func delete(tag: String) throws(DeviceSignerError)
    func allTags(prefix: String) -> [String]
}

struct SystemKeychainItemStore: KeychainItemStore {
    private let service = "com.crossmint.devicesigner"

    func save(_ data: Data, tag: String, accessControl: SecAccessControl?) throws(DeviceSignerError) {
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

    func load(tag: String, prompt: String?, authContext: LAContext?) -> Data? {
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

    func allTags(prefix: String) -> [String] {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecReturnAttributes: true,
            kSecMatchLimit: kSecMatchLimitAll
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                logger.error("Unexpected Keychain error in allTags: \(status)")
            }
            return []
        }
        guard let items = result as? [[CFString: Any]] else {
            return []
        }
        return items.compactMap { $0[kSecAttrAccount] as? String }.filter { $0.hasPrefix(prefix) }
    }
}

struct DeviceSignerKeychainStorage {
    static let pendingKeyPrefix = "crossmint.device.pending."
    static let walletKeyPrefix = "crossmint.device.wallet."

    private let store: KeychainItemStore

    init(store: KeychainItemStore = SystemKeychainItemStore()) {
        self.store = store
    }

    func save(_ data: Data, tag: String, accessControl: SecAccessControl? = nil) throws(DeviceSignerError) {
        try store.save(data, tag: tag, accessControl: accessControl)
    }

    func load(tag: String, prompt: String? = nil, authContext: LAContext? = nil) -> Data? {
        store.load(tag: tag, prompt: prompt, authContext: authContext)
    }

    func delete(tag: String) throws(DeviceSignerError) {
        try store.delete(tag: tag)
    }

    func allTags(prefix: String) -> [String] {
        store.allTags(prefix: prefix)
    }

    func rename(from oldTag: String, to newTag: String) throws(DeviceSignerError) {
        guard let data = load(tag: oldTag) else {
            if load(tag: newTag) != nil { return }
            throw DeviceSignerError.keyNotFound
        }
        try delete(tag: oldTag)
        try save(data, tag: newTag)
    }

    func hasMatchingKey(publicKeyBase64: String, reconstructPublicKey: (Data) -> String?) -> Bool {
        if load(tag: "\(Self.pendingKeyPrefix)\(publicKeyBase64)") != nil { return true }
        return allTags(prefix: Self.walletKeyPrefix).contains { tag in
            guard let keyData = load(tag: tag) else { return false }
            return reconstructPublicKey(keyData) == publicKeyBase64
        }
    }
}
