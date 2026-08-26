extension DeviceSignerKeyStorage where Self == SecureEnclaveKeyStorage {
    /// The key storage backend for the current device: Secure Enclave-backed storage
    /// when the hardware is available, otherwise Keychain-backed storage.
    public static var `default`: DeviceSignerKeyStorage {
        let secureEnclaveStorage = SecureEnclaveKeyStorage()
        if secureEnclaveStorage.isAvailable() {
            return secureEnclaveStorage
        }
        return KeychainKeyStorage()
    }
}
