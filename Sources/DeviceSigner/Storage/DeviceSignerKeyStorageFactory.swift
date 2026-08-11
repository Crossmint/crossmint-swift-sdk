/// Selects the device signer key storage backend for the current device.
public enum DeviceSignerKeyStorageFactory {
    /// Returns Secure Enclave-backed storage when the hardware is available,
    /// otherwise Keychain-backed storage.
    public static func make() -> any DeviceSignerKeyStorage {
        let secureEnclaveStorage = SecureEnclaveKeyStorage()
        if secureEnclaveStorage.isAvailable() {
            return secureEnclaveStorage
        }
        return KeychainKeyStorage()
    }
}
