import Foundation
import Testing
import TestsUtils
@testable import DeviceSigner

#if targetEnvironment(simulator)
@Suite("SecureEnclaveKeyStorage over an in-memory store")
struct SecureEnclaveKeyStorageTests {
    private let address = "7ZN9rAofFVVP1WKqfKozsVWQYcDj2u9juYyRkrKUVR8Y"
    private let store = InMemoryKeychainItemStore()

    private var walletTag: String { "\(DeviceSignerKeychainStorage.walletKeyPrefix)\(address)" }

    @Test func cannotGenerateAKeyWithoutTheHardware() async {
        let storage = SecureEnclaveKeyStorage.inMemory(store)

        #expect(storage.isAvailable() == false)
        await #expect {
            try await storage.generateKey(address: address)
        } throws: { error in
            guard case .keyGenerationFailed = error as? DeviceSignerError else { return false }
            return true
        }
        #expect(store.tags.isEmpty)
    }

    @Test func treatsAnItemTheEnclaveCannotUseAsMissingWhenReading() async throws {
        let storage = SecureEnclaveKeyStorage.inMemory(store)
        try store.save(Data(repeating: 0xff, count: 8), tag: walletTag, accessControl: nil)

        #expect(await storage.getKey(address: address) == nil)
        #expect(storage.hasKey(publicKeyBase64: "BAAA") == false)
    }

    @Test func reportsSigningFailedWhenAskedToSignWithAnItemTheEnclaveCannotUse() async throws {
        let storage = SecureEnclaveKeyStorage.inMemory(store)
        try store.save(Data(repeating: 0xff, count: 8), tag: walletTag, accessControl: nil)

        await #expect {
            try await storage.signMessage(address: address, message: Data("m".utf8).base64EncodedString())
        } throws: { error in
            guard case .signingFailed(let operation, _) = error as? DeviceSignerError else { return false }
            return operation == "Secure Enclave key reconstruction"
        }
    }
}
#endif
