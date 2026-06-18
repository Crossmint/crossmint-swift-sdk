//
//  DeviceSignerKeyStorageTests.swift
//  CrossmintSDK
//
//  Regression coverage for WAL-10734. The device signer fails with `keyNotFound`
//  on devices where the private key is no longer present (for example after a
//  restore onto new hardware, where the `ThisDeviceOnly` key does not survive).
//
//  These tests drive the keychain layer through an in-memory store so the
//  rename/lookup logic is exercised without Keychain entitlements.
//

import Foundation
import LocalAuthentication
import Security
import Testing
@testable import DeviceSigner

/// In-memory `KeychainItemStore` for tests. Each test gets its own instance, so no
/// locking is needed; access within a test is sequential.
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

    // MARK: - rename / mapAddressToKey

    @Test("rename moves a pending key to the wallet-address tag")
    func renameMovesPendingToWallet() throws {
        let keychain = DeviceSignerKeychainStorage(store: InMemoryKeychainItemStore())
        let data = Data("private-key".utf8)
        try keychain.save(data, tag: pendingTag("PUB"))

        try keychain.rename(from: pendingTag("PUB"), to: walletTag("0xabc"))

        #expect(keychain.load(tag: pendingTag("PUB")) == nil)
        #expect(keychain.load(tag: walletTag("0xabc")) == data)
    }

    /// The defense-in-depth half of the fix: when the pending key is gone but the
    /// address is already keyed, a repeated rename is a no-op rather than a failure.
    @Test("rename is a no-op when the destination already holds a key")
    func renameIdempotentWhenDestinationExists() throws {
        let keychain = DeviceSignerKeychainStorage(store: InMemoryKeychainItemStore())
        let data = Data("already-mapped".utf8)
        try keychain.save(data, tag: walletTag("0xabc"))

        // No pending item exists, but the wallet-address tag does: must not throw.
        try keychain.rename(from: pendingTag("PUB"), to: walletTag("0xabc"))

        #expect(keychain.load(tag: walletTag("0xabc")) == data)
    }

    /// When neither a pending nor a wallet-address item exists, the failure is a
    /// typed `keyNotFound` the orchestration can branch on to trigger re-registration.
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

    // MARK: - hasMatchingKey (the honest hasKey primitive)

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

    /// The core of the production bug: once the key material is gone, `hasMatchingKey`
    /// must report false. An index that only records "was this key ever generated
    /// here" returns true and sends the SDK into a rename/sign loop that can never
    /// succeed.
    @Test("hasMatchingKey reflects real presence, not generation history")
    func hasMatchingKeyFalseAfterDeletion() throws {
        let keychain = DeviceSignerKeychainStorage(store: InMemoryKeychainItemStore())
        try keychain.save(Data("k".utf8), tag: pendingTag("PUB"))
        #expect(keychain.hasMatchingKey(publicKeyBase64: "PUB") { _ in nil } == true)

        try keychain.delete(tag: pendingTag("PUB"))
        #expect(keychain.hasMatchingKey(publicKeyBase64: "PUB") { _ in nil } == false)
    }
}
