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
/// ``DefaultCrossmintWallets`` selects this implementation automatically when Secure Enclave
/// is available, and falls back to ``KeychainDeviceSignerKeyStorage`` when it is not.
public final class SecureEnclaveKeyStorage: DeviceSignerKeyStorage {
    private let keychain = DeviceSignerKeychainStorage()
    private let biometricPolicy: BiometricPolicy

    /// Creates a Secure Enclave key storage.
    public init() {
        self.biometricPolicy = .none
    }

    init(biometricPolicy: BiometricPolicy) {
        self.biometricPolicy = biometricPolicy
    }

    public func isAvailable() -> Bool {
        SecureEnclave.isAvailable
    }

    public func generateKey(address: String?) async throws(DeviceSignerError) -> String {
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

        let publicKeyBase64 = uncompressedPublicKey(from: key.publicKey.rawRepresentation)

        let tag: String
        if let address {
            tag = "\(walletKeyPrefix)\(address)"
        } else {
            tag = "\(pendingKeyPrefix)\(publicKeyBase64)"
        }

        try keychain.save(key.dataRepresentation, tag: tag)

        return publicKeyBase64
    }

    public func mapAddressToKey(address: String, publicKeyBase64: String) async throws(DeviceSignerError) {
        try keychain.rename(
            from: "\(pendingKeyPrefix)\(publicKeyBase64)",
            to: "\(walletKeyPrefix)\(address)"
        )
    }

    public func getKey(address: String) async -> String? {
        let tag = "\(walletKeyPrefix)\(address)"
        guard let keyData = keychain.load(tag: tag),
              let key = try? SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: keyData) else {
            return nil
        }
        return uncompressedPublicKey(from: key.publicKey.rawRepresentation)
    }

    public func signMessage(
        address: String,
        message: String
    ) async throws(DeviceSignerError) -> (r: String, s: String) {
        let tag = "\(walletKeyPrefix)\(address)"
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
        try keychain.delete(tag: "\(walletKeyPrefix)\(address)")
    }

    public func deletePendingKey(publicKeyBase64: String) async throws(DeviceSignerError) {
        try keychain.delete(tag: "\(pendingKeyPrefix)\(publicKeyBase64)")
    }

    public func hasKey(publicKeyBase64: String) -> Bool {
        keychain.hasMatchingKey(publicKeyBase64: publicKeyBase64) { [self] keyData in
            guard let key = try? SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: keyData) else { return nil }
            return uncompressedPublicKey(from: key.publicKey.rawRepresentation)
        }
    }

    // MARK: - Private helper

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

}
