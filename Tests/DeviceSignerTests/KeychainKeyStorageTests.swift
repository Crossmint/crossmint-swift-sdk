import Foundation
import Testing
import TestsUtils
@testable import DeviceSigner

@Suite("KeychainKeyStorage over an in-memory store")
struct KeychainKeyStorageTests {
    private let address = "7ZN9rAofFVVP1WKqfKozsVWQYcDj2u9juYyRkrKUVR8Y"
    private let message = Data("approval-message".utf8).base64EncodedString()
    private let store = InMemoryKeychainItemStore()

    private var walletTag: String { "\(DeviceSignerKeychainStorage.walletKeyPrefix)\(address)" }

    @Test func generatesAKeyWhoseSignatureVerifies() async throws {
        let storage = KeychainKeyStorage.inMemory(store)

        let publicKey = try await storage.generateKey(address: address)
        let signature = try await storage.signMessage(address: address, message: message)

        #expect(Data(base64Encoded: publicKey)?.count == 65)
        #expect(await storage.getKey(address: address) == publicKey)
        #expect(P256SignatureCheck.verifies(
            r: signature.r, s: signature.s, publicKeyBase64: publicKey, messageBase64: message
        ))
    }

    @Test func mapsAPendingKeyToTheWalletAddress() async throws {
        let storage = KeychainKeyStorage.inMemory(store)

        let publicKey = try await storage.generateKey(address: nil)
        #expect(store.tags == ["\(DeviceSignerKeychainStorage.pendingKeyPrefix)\(publicKey)"])

        try await storage.mapAddressToKey(address: address, publicKeyBase64: publicKey)

        #expect(store.tags == [walletTag])
        #expect(storage.hasKey(publicKeyBase64: publicKey))
        #expect(await storage.getKey(address: address) == publicKey)
    }

    @Test func reportsKeyNotFoundWhenTheStoreHoldsNoKey() async {
        let storage = KeychainKeyStorage.inMemory(store)

        await #expect {
            try await storage.signMessage(address: address, message: message)
        } throws: { error in
            guard case .keyNotFound = error as? DeviceSignerError else { return false }
            return true
        }
    }

    @Test func treatsAnItemNoKeyCanBeBuiltFromAsMissing() async throws {
        let storage = KeychainKeyStorage.inMemory(store)
        let publicKey = try await storage.generateKey(address: address)

        store.corrupt(tag: walletTag)

        #expect(store.tags == [walletTag])
        #expect(await storage.getKey(address: address) == nil)
        #expect(storage.hasKey(publicKeyBase64: publicKey) == false)
        await #expect {
            try await storage.signMessage(address: address, message: message)
        } throws: { error in
            guard case .keyNotFound = error as? DeviceSignerError else { return false }
            return true
        }
    }

    @Test func surfacesAStoreFailureAsStorageError() async {
        store.saveError = .storageError(errSecInteractionNotAllowed)
        let storage = KeychainKeyStorage.inMemory(store)

        await #expect {
            try await storage.generateKey(address: address)
        } throws: { error in
            guard case .storageError(let status) = error as? DeviceSignerError else { return false }
            return status == errSecInteractionNotAllowed
        }
        #expect(store.tags.isEmpty)
    }

    @Test func deletesTheWalletKey() async throws {
        let storage = KeychainKeyStorage.inMemory(store)
        _ = try await storage.generateKey(address: address)

        try await storage.deleteKey(address: address)

        #expect(store.tags.isEmpty)
        #expect(await storage.getKey(address: address) == nil)
    }

    @Test func rejectsAMessageThatIsNotBase64() async throws {
        let storage = KeychainKeyStorage.inMemory(store)
        _ = try await storage.generateKey(address: address)

        await #expect {
            try await storage.signMessage(address: address, message: "not base64!")
        } throws: { error in
            guard case .invalidMessage = error as? DeviceSignerError else { return false }
            return true
        }
    }
}
