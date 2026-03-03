import Security

public enum DeviceSignerError: Error, Sendable {
    case hardwareUnavailable
    case keyNotFound
    case keyGenerationFailed
    case signingFailed
    case storageError(OSStatus)
    case invalidMessage
}

public protocol DeviceSignerKeyStorage: Sendable {
    func isAvailable() async -> Bool
    func generateKey(address: String?) async throws(DeviceSignerError) -> String
    func mapAddressToKey(address: String, publicKeyBase64: String) async throws(DeviceSignerError)
    func getKey(address: String) async -> String?
    func signMessage(
        address: String,
        message: String
    ) async throws(DeviceSignerError) -> (r: String, s: String)
    func deleteKey(address: String) async throws(DeviceSignerError)
}
