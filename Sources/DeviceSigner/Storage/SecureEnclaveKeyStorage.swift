//
//  SecureEnclaveKeyStorage.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 3/3/26.
//

import CryptoKit
import Foundation
import Security

/// A ``DeviceSignerKeyStorage`` implementation backed by the iOS Secure Enclave.
///
/// Keys are non-extractable P-256 private keys generated and stored directly in the
/// Secure Enclave hardware. Signing operations execute inside the enclave; the raw key
/// material never leaves the chip.
///
/// Check ``SecureEnclave/isAvailable`` before instantiating this class. On simulators,
/// use ``SoftwareDeviceSignerKeyStorage`` for development only. On physical devices without
/// a Secure Enclave, the device signer feature should not be used — prefer an alternative
/// signer such as email or passkey.
public final class SecureEnclaveKeyStorage: DeviceSignerKeyStorage {
    private let keychain = DeviceSignerKeychainStorage()
    private let biometricPolicy: BiometricPolicy

    /// Creates a Secure Enclave key storage with the given biometric policy.
    ///
    /// - Parameter biometricPolicy: When to require biometric authentication for signing.
    ///   Defaults to ``BiometricPolicy/none``.
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

        try keychain.save(key.dataRepresentation, tag: tag)

        return publicKeyBase64
    }

    public func mapAddressToKey(address: String, publicKeyBase64: String) async throws(DeviceSignerError) {
        let oldTag = "crossmint.device.pending.\(publicKeyBase64)"
        let newTag = "crossmint.device.wallet.\(address)"
        try keychain.rename(from: oldTag, to: newTag)
    }

    public func getKey(address: String) async -> String? {
        let tag = "crossmint.device.wallet.\(address)"
        guard let keyData = keychain.load(tag: tag),
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
        guard let keyData = keychain.load(tag: tag) else {
            throw DeviceSignerError.keyNotFound
        }

        let key: SecureEnclave.P256.Signing.PrivateKey
        do {
            key = try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: keyData)
        } catch {
            // Key data was found but the SE key is unusable (e.g. biometric enrollment changed)
            throw DeviceSignerError.signingFailed
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
        try keychain.delete(tag: tag)
    }

    public func deletePendingKey(publicKeyBase64: String) async throws(DeviceSignerError) {
        let tag = "crossmint.device.pending.\(publicKeyBase64)"
        try keychain.delete(tag: tag)
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
