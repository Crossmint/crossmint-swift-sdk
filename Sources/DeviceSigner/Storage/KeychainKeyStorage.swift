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
/// The `DeviceSignerKeyStorage.default` property selects ``SecureEnclaveKeyStorage`` when
/// Secure Enclave is available and falls back to this implementation when it is not.
public final class KeychainKeyStorage: DeviceSignerKeyStorage {
    private let biometricPolicy: BiometricPolicy
    private let keychain = DeviceSignerKeychainStorage()

    /// Creates a Keychain key storage.
    public init() {
        self.biometricPolicy = .none
    }

    init(biometricPolicy: BiometricPolicy) {
        self.biometricPolicy = biometricPolicy
    }

    public func isAvailable() -> Bool {
        true
    }

    public func generateKey(address: String?) async throws(DeviceSignerError) -> String {
        let key = P256.Signing.PrivateKey()
        let publicKeyBase64 = uncompressedPublicKey(from: key.publicKey.rawRepresentation)

        let tag: String
        if let address {
            tag = "\(walletKeyPrefix)\(address)"
        } else {
            tag = "\(pendingKeyPrefix)\(publicKeyBase64)"
        }

        // Store the 32-byte private key scalar
        try keychain.save(key.rawRepresentation, tag: tag, accessControl: makeAccessControl())

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
              let key = try? P256.Signing.PrivateKey(rawRepresentation: keyData) else {
            return nil
        }
        return uncompressedPublicKey(from: key.publicKey.rawRepresentation)
    }

    public func signMessage(
        address: String,
        message: String
    ) async throws(DeviceSignerError) -> (r: String, s: String) {
        let tag = "\(walletKeyPrefix)\(address)"
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
            throw DeviceSignerError.signingFailed(
                operation: "Keychain signature",
                underlyingError: error
            )
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
            guard let key = try? P256.Signing.PrivateKey(rawRepresentation: keyData) else { return nil }
            return uncompressedPublicKey(from: key.publicKey.rawRepresentation)
        }
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

}
