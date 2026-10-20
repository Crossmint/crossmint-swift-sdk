import DeviceSigner
import Foundation
import LocalAuthentication
import Security

package final class InMemoryKeychainItemStore: KeychainItemStore, @unchecked Sendable {
    package private(set) var items: [String: Data] = [:]
    package var saveError: DeviceSignerError?
    package var deleteError: DeviceSignerError?
    /// Reads return nothing, as the system store does while the device is locked.
    package var locked = false

    package init() {}

    package var tags: [String] { Array(items.keys).sorted() }

    package static func walletTag(address: String) -> String {
        "\(DeviceSignerKeychainStorage.walletKeyPrefix)\(address)"
    }

    package static func pendingTag(publicKeyBase64: String) -> String {
        "\(DeviceSignerKeychainStorage.pendingKeyPrefix)\(publicKeyBase64)"
    }

    /// Keeps the item but makes its bytes unusable as a key, as after a restore from backup.
    package func corrupt(tag: String) {
        items[tag] = Data(repeating: 0xff, count: 8)
    }

    package func save(_ data: Data, tag: String, accessControl: SecAccessControl?) throws(DeviceSignerError) {
        if let saveError { throw saveError }
        items[tag] = data
    }

    package func load(tag: String, prompt: String?, authContext: LAContext?) -> Data? {
        locked ? nil : items[tag]
    }

    package func delete(tag: String) throws(DeviceSignerError) {
        if let deleteError { throw deleteError }
        items[tag] = nil
    }

    package func allTags(prefix: String) -> [String] {
        items.keys.filter { $0.hasPrefix(prefix) }
    }
}

extension KeychainKeyStorage {
    package static func inMemory(
        _ store: InMemoryKeychainItemStore = InMemoryKeychainItemStore()
    ) -> KeychainKeyStorage {
        KeychainKeyStorage(store: store)
    }
}

extension SecureEnclaveKeyStorage {
    /// Key generation still needs the hardware; on a simulator only the read paths run.
    package static func inMemory(
        _ store: InMemoryKeychainItemStore = InMemoryKeychainItemStore()
    ) -> SecureEnclaveKeyStorage {
        SecureEnclaveKeyStorage(store: store)
    }
}
