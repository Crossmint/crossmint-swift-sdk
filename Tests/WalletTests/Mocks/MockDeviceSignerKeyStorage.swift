import DeviceSigner
import Foundation

final class MockDeviceSignerKeyStorage: DeviceSignerKeyStorage, @unchecked Sendable {
    private(set) var keysByAddress: [String: String] = [:]
    private(set) var pendingKeys: Set<String> = []
    private(set) var deleteKeyCallCount = 0
    private(set) var deletePendingKeyCallCount = 0

    func isAvailable() -> Bool { true }

    func generateKey(address: String?) async throws(DeviceSignerError) -> String {
        var rawKey = Data([0x04])
        rawKey.append(Data((0..<64).map { UInt8($0) }))
        let publicKeyBase64 = rawKey.base64EncodedString()
        if let address {
            keysByAddress[address] = publicKeyBase64
        } else {
            pendingKeys.insert(publicKeyBase64)
        }
        return publicKeyBase64
    }

    func mapAddressToKey(address: String, publicKeyBase64: String) async throws(DeviceSignerError) {
        pendingKeys.remove(publicKeyBase64)
        keysByAddress[address] = publicKeyBase64
    }

    func getKey(address: String) async -> String? {
        keysByAddress[address]
    }

    func signMessage(
        address: String,
        message: String
    ) async throws(DeviceSignerError) -> (r: String, s: String) {
        ("0xr", "0xs")
    }

    func deleteKey(address: String) async throws(DeviceSignerError) {
        deleteKeyCallCount += 1
        keysByAddress[address] = nil
    }

    func deletePendingKey(publicKeyBase64: String) async throws(DeviceSignerError) {
        deletePendingKeyCallCount += 1
        pendingKeys.remove(publicKeyBase64)
    }

    func hasKey(publicKeyBase64: String) -> Bool {
        pendingKeys.contains(publicKeyBase64) || keysByAddress.values.contains(publicKeyBase64)
    }
}
