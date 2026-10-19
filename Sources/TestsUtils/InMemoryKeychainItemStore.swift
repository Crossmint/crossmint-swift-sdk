import DeviceSigner
import Foundation
import LocalAuthentication
import Security

public final class InMemoryKeychainItemStore: KeychainItemStore, @unchecked Sendable {
    public private(set) var items: [String: Data] = [:]
    public var saveError: DeviceSignerError?
    public var deleteError: DeviceSignerError?

    public init() {}

    public var tags: [String] { Array(items.keys).sorted() }

    public static func walletTag(address: String) -> String {
        "\(DeviceSignerKeychainStorage.walletKeyPrefix)\(address)"
    }

    public static func pendingTag(publicKeyBase64: String) -> String {
        "\(DeviceSignerKeychainStorage.pendingKeyPrefix)\(publicKeyBase64)"
    }

    /// Keeps the item but makes its bytes unusable as a key, as after a restore from backup.
    public func corrupt(tag: String) {
        items[tag] = Data(repeating: 0xff, count: 8)
    }

    public func save(_ data: Data, tag: String, accessControl: SecAccessControl?) throws(DeviceSignerError) {
        if let saveError { throw saveError }
        items[tag] = data
    }

    public func load(tag: String, prompt: String?, authContext: LAContext?) -> Data? {
        items[tag]
    }

    public func delete(tag: String) throws(DeviceSignerError) {
        if let deleteError { throw deleteError }
        items[tag] = nil
    }

    public func allTags(prefix: String) -> [String] {
        items.keys.filter { $0.hasPrefix(prefix) }
    }
}

extension KeychainKeyStorage {
    public static func inMemory(
        _ store: InMemoryKeychainItemStore = InMemoryKeychainItemStore()
    ) -> KeychainKeyStorage {
        KeychainKeyStorage(store: store)
    }
}

extension SecureEnclaveKeyStorage {
    /// Key generation still needs the hardware; on a simulator only the read paths run.
    public static func inMemory(
        _ store: InMemoryKeychainItemStore = InMemoryKeychainItemStore()
    ) -> SecureEnclaveKeyStorage {
        SecureEnclaveKeyStorage(store: store)
    }
}
