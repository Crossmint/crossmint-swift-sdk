/// Selects the device signer key storage backend for the current device.
@available(*, deprecated, message: "Use the DeviceSignerKeyStorage.default property instead.")
public enum DeviceSignerKeyStorageFactory {
    /// Returns Secure Enclave-backed storage when the hardware is available,
    /// otherwise Keychain-backed storage.
    public static func make() -> DeviceSignerKeyStorage { .default }
}
