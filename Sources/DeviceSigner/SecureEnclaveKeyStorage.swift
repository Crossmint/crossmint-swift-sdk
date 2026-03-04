import CryptoKit
import Foundation
import Security

public final class SecureEnclaveKeyStorage: DeviceSignerKeyStorage {
    private let biometricPolicy: BiometricPolicy

    public init(biometricPolicy: BiometricPolicy = .none) {
        self.biometricPolicy = biometricPolicy
    }

    public func isAvailable() async -> Bool {
        SecureEnclave.isAvailable
    }

    public func generateKey(address: String?) async throws(DeviceSignerError) -> String {
        guard SecureEnclave.isAvailable else {
            throw DeviceSignerError.hardwareUnavailable
        }

        let accessControl = makeAccessControl()
        guard let access = accessControl else {
            throw DeviceSignerError.keyGenerationFailed
        }

        let key: SecureEnclave.P256.Signing.PrivateKey
        do {
            key = try SecureEnclave.P256.Signing.PrivateKey(accessControl: access)
        } catch {
            throw DeviceSignerError.keyGenerationFailed
        }

        let rawPublicKey = key.publicKey.rawRepresentation  // 64 bytes: x‖y
        let publicKeyBase64 = rawPublicKey.base64EncodedString()

        let tag: String
        if let address {
            tag = "crossmint.device.wallet.\(address)"
        } else {
            tag = "crossmint.device.pending.\(publicKeyBase64)"
        }

        try DeviceSignerKeychainStorage.save(key.dataRepresentation, tag: tag)

        return publicKeyBase64
    }

    public func mapAddressToKey(address: String, publicKeyBase64: String) async throws(DeviceSignerError) {
        let oldTag = "crossmint.device.pending.\(publicKeyBase64)"
        let newTag = "crossmint.device.wallet.\(address)"
        try DeviceSignerKeychainStorage.rename(from: oldTag, to: newTag)
    }

    public func getKey(address: String) async -> String? {
        let tag = "crossmint.device.wallet.\(address)"
        guard let keyData = DeviceSignerKeychainStorage.load(tag: tag),
              let key = try? SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: keyData) else {
            return nil
        }
        return key.publicKey.rawRepresentation.base64EncodedString()
    }

    public func signMessage(
        address: String,
        message: String
    ) async throws(DeviceSignerError) -> (r: String, s: String) {
        let tag = "crossmint.device.wallet.\(address)"
        guard let keyData = DeviceSignerKeychainStorage.load(tag: tag) else {
            throw DeviceSignerError.keyNotFound
        }

        let key: SecureEnclave.P256.Signing.PrivateKey
        do {
            key = try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: keyData)
        } catch {
            throw DeviceSignerError.keyNotFound
        }

        guard let messageData = Data(base64Encoded: message) else {
            throw DeviceSignerError.invalidMessage
        }

        let ecdsaSignature: P256.Signing.ECDSASignature
        do {
            ecdsaSignature = try key.signature(for: messageData)
        } catch {
            throw DeviceSignerError.signingFailed
        }

        // rawRepresentation = 64 bytes: r (32) ‖ s (32)
        let raw = ecdsaSignature.rawRepresentation
        let rHex = "0x" + hexString(from: raw.prefix(32))
        let sHex = "0x" + hexString(from: raw.suffix(32))
        return (r: rHex, s: sHex)
    }

    public func deleteKey(address: String) async throws(DeviceSignerError) {
        let tag = "crossmint.device.wallet.\(address)"
        try DeviceSignerKeychainStorage.delete(tag: tag)
    }

    // MARK: - Private helpers

    private func makeAccessControl() -> SecAccessControl? {
        let flags: SecAccessControlCreateFlags
        switch biometricPolicy {
        case .none:
            flags = [.privateKeyUsage]
        case .always:
            flags = [.privateKeyUsage, .biometryCurrentSet]
        }
        return SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            flags,
            nil
        )
    }

    private func hexString<D: DataProtocol>(from data: D) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}
