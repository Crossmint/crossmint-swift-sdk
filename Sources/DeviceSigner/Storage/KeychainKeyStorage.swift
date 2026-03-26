//
//  KeychainKeyStorage.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 3/3/26.
//

import CryptoKit
import Foundation
import Security

/// A ``DeviceSignerKeyStorage`` implementation using P-256 keys stored in the Keychain.
///
/// Keys are stored as Keychain-protected items rather than in dedicated hardware. This is the
/// fallback used when Secure Enclave is unavailable.
///
/// ``DefaultCrossmintWallets`` selects ``SecureEnclaveKeyStorage`` when Secure Enclave is
/// available and falls back to this implementation when ``SecureEnclave/isAvailable`` returns `false`.
public final class KeychainKeyStorage: DeviceSignerKeyStorage {
    private let biometricPolicy: BiometricPolicy
    private let keychain = DeviceSignerKeychainStorage()

    /// Creates a Keychain key storage with the given biometric policy.
    ///
    /// - Parameter biometricPolicy: When to require biometric authentication for signing.
    ///   Defaults to ``BiometricPolicy/none``.
    public init(biometricPolicy: BiometricPolicy = .none) {
        self.biometricPolicy = biometricPolicy
    }

    public func isAvailable() async -> Bool {
        true
    }

    public func generateKey(address: String?) async throws(DeviceSignerError) -> String {
        let key = P256.Signing.PrivateKey()
        var uncompressed = Data([0x04])
        uncompressed.append(key.publicKey.rawRepresentation)  // 65 bytes: 0x04 ‖ x ‖ y
        let publicKeyBase64 = uncompressed.base64EncodedString()

        let tag: String
        if let address {
            tag = "crossmint.device.wallet.\(address)"
        } else {
            tag = "crossmint.device.pending.\(publicKeyBase64)"
        }

        // Store the 32-byte private key scalar
        try keychain.save(key.rawRepresentation, tag: tag, accessControl: makeAccessControl())

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
              let key = try? P256.Signing.PrivateKey(rawRepresentation: keyData) else {
            return nil
        }
        var uncompressed = Data([0x04])
        uncompressed.append(key.publicKey.rawRepresentation)
        return uncompressed.base64EncodedString()
    }

    public func signMessage(
        address: String,
        message: String
    ) async throws(DeviceSignerError) -> (r: String, s: String) {
        let tag = "crossmint.device.wallet.\(address)"
        guard let keyData = keychain.load(tag: tag),
              let key = try? P256.Signing.PrivateKey(rawRepresentation: keyData) else {
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
        try keychain.delete(tag: tag)
    }

    public func deletePendingKey(publicKeyBase64: String) async throws(DeviceSignerError) {
        let tag = "crossmint.device.pending.\(publicKeyBase64)"
        try keychain.delete(tag: tag)
    }

    public func hasKey(pubKey64: String) -> Bool {
        keychain.load(tag: "crossmint.device.pending.\(pubKey64)") != nil
    }

    // MARK: - Private helpers

    private func makeAccessControl() -> SecAccessControl? {
        switch biometricPolicy {
        case .none:
            return nil
        case .always:
            return SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .biometryCurrentSet,
                nil
            )
        }
    }

    private func hexString<D: DataProtocol>(from data: D) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}
