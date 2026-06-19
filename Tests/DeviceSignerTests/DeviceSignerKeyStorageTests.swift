import Foundation
import LocalAuthentication
import Security
import Testing
@testable import DeviceSigner

final class InMemoryKeychainItemStore: KeychainItemStore, @unchecked Sendable {
    private var items: [String: Data] = [:]

    func save(_ data: Data, tag: String, accessControl: SecAccessControl?) throws(DeviceSignerError) {
        items[tag] = data
    }

    func load(tag: String, prompt: String?, authContext: LAContext?) -> Data? {
        items[tag]
    }

    func delete(tag: String) throws(DeviceSignerError) {
        items[tag] = nil
    }

    func allTags(prefix: String) -> [String] {
        items.keys.filter { $0.hasPrefix(prefix) }
    }
}

@Suite("DeviceSigner keychain storage")
struct DeviceSignerKeychainStorageTests {

    private func pendingTag(_ publicKey: String) -> String {
        "\(DeviceSignerKeychainStorage.pendingKeyPrefix)\(publicKey)"
    }

    private func walletTag(_ address: String) -> String {
        "\(DeviceSignerKeychainStorage.walletKeyPrefix)\(address)"
    }

    @Test("rename moves a pending key to the wallet-address tag")
    func renameMovesPendingToWallet() throws {
        let keychain = DeviceSignerKeychainStorage(store: InMemoryKeychainItemStore())
        let data = Data("private-key".utf8)
        try keychain.save(data, tag: pendingTag("PUB"))

        try keychain.rename(from: pendingTag("PUB"), to: walletTag("0xabc"))

        #expect(keychain.load(tag: pendingTag("PUB")) == nil)
        #expect(keychain.load(tag: walletTag("0xabc")) == data)
    }

    @Test("rename is a no-op when the destination already holds a key")
    func renameIdempotentWhenDestinationExists() throws {
        let keychain = DeviceSignerKeychainStorage(store: InMemoryKeychainItemStore())
        let data = Data("already-mapped".utf8)
        try keychain.save(data, tag: walletTag("0xabc"))

        try keychain.rename(from: pendingTag("PUB"), to: walletTag("0xabc"))

        #expect(keychain.load(tag: walletTag("0xabc")) == data)
    }

    @Test("rename throws keyNotFound when no key exists anywhere")
    func renameThrowsKeyNotFoundWhenNothingPresent() {
        let keychain = DeviceSignerKeychainStorage(store: InMemoryKeychainItemStore())

        var caught: DeviceSignerError?
        do {
            try keychain.rename(from: pendingTag("PUB"), to: walletTag("0xabc"))
        } catch {
            caught = error
        }
        guard case .keyNotFound = caught else {
            Issue.record("expected keyNotFound, got \(String(describing: caught))")
            return
        }
    }

    @Test("hasMatchingKey is false when no key material is present")
    func hasMatchingKeyFalseWhenAbsent() {
        let keychain = DeviceSignerKeychainStorage(store: InMemoryKeychainItemStore())
        #expect(keychain.hasMatchingKey(publicKeyBase64: "PUB") { _ in nil } == false)
    }

    @Test("hasMatchingKey is true for a pending key")
    func hasMatchingKeyTrueForPending() throws {
        let keychain = DeviceSignerKeychainStorage(store: InMemoryKeychainItemStore())
        try keychain.save(Data("k".utf8), tag: pendingTag("PUB"))
        #expect(keychain.hasMatchingKey(publicKeyBase64: "PUB") { _ in nil } == true)
    }

    @Test("hasMatchingKey is true for a key already mapped to an address")
    func hasMatchingKeyTrueForMappedWallet() throws {
        let keychain = DeviceSignerKeychainStorage(store: InMemoryKeychainItemStore())
        let keyData = Data("mapped".utf8)
        try keychain.save(keyData, tag: walletTag("0xabc"))
        #expect(keychain.hasMatchingKey(publicKeyBase64: "PUB") { $0 == keyData ? "PUB" : nil } == true)
    }

    @Test("hasMatchingKey reflects real presence, not generation history")
    func hasMatchingKeyFalseAfterDeletion() throws {
        let keychain = DeviceSignerKeychainStorage(store: InMemoryKeychainItemStore())
        try keychain.save(Data("k".utf8), tag: pendingTag("PUB"))
        #expect(keychain.hasMatchingKey(publicKeyBase64: "PUB") { _ in nil } == true)

        try keychain.delete(tag: pendingTag("PUB"))
        #expect(keychain.hasMatchingKey(publicKeyBase64: "PUB") { _ in nil } == false)
    }
}
