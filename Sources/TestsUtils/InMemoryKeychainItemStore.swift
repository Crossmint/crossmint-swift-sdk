import DeviceSigner
import Foundation
import LocalAuthentication
import Security

/// A `KeychainItemStore` that keeps items in memory, for the sandbox tier.
///
/// Pair it with ``KeychainKeyStorage/inMemory(_:)`` to run the real P-256 key lifecycle with no
/// Keychain and no Secure Enclave. The overrides reproduce the device states clients have hit.
public final class InMemoryKeychainItemStore: KeychainItemStore, @unchecked Sendable {
    public private(set) var items: [String: Data] = [:]
    /// Thrown by every `save` while set.
    public var saveError: DeviceSignerError?
    /// Thrown by every `delete` while set.
    public var deleteError: DeviceSignerError?

    public init() {}

    public var tags: [String] { Array(items.keys).sorted() }

    /// The tag under which a key mapped to `address` is stored.
    public static func walletTag(address: String) -> String {
        "\(DeviceSignerKeychainStorage.walletKeyPrefix)\(address)"
    }

    /// The tag under which a key not yet mapped to a wallet is stored.
    public static func pendingTag(publicKeyBase64: String) -> String {
        "\(DeviceSignerKeychainStorage.pendingKeyPrefix)\(publicKeyBase64)"
    }

    /// Keeps the item under `tag` but replaces its contents with bytes no key can be built from:
    /// the "record remains, key gone" state of a device restored from backup.
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
    /// Real P-256 generation and signing over an in-memory store.
    public static func inMemory(
        _ store: InMemoryKeychainItemStore = InMemoryKeychainItemStore()
    ) -> KeychainKeyStorage {
        KeychainKeyStorage(store: store)
    }
}

extension SecureEnclaveKeyStorage {
    /// The Secure Enclave storage over an in-memory store. Key generation still needs the hardware,
    /// so on a simulator only the read paths can run.
    public static func inMemory(
        _ store: InMemoryKeychainItemStore = InMemoryKeychainItemStore()
    ) -> SecureEnclaveKeyStorage {
        SecureEnclaveKeyStorage(store: store)
    }
}
