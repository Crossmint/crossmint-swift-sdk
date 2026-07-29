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
        #if targetEnvironment(simulator)
        return false
        #else
        return SecureEnclave.isAvailable
        #endif
    }

    public func generateKey(address: String?) async throws(DeviceSignerError) -> String {
        guard isAvailable() else {
            throw DeviceSignerError.keyGenerationFailed
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
              let key = try? SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: keyData),
              isUsable(key) else {
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
            throw DeviceSignerError.signingFailed(
                operation: "Secure Enclave key reconstruction",
                underlyingError: error
            )
        }

        guard let messageData = Data(base64Encoded: message) else {
            throw DeviceSignerError.invalidMessage
        }

        let ecdsaSignature: P256.Signing.ECDSASignature
        do {
            ecdsaSignature = try key.signature(for: messageData)
        } catch {
            throw DeviceSignerError.signingFailed(
                operation: "Secure Enclave signature",
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
            guard let key = try? SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: keyData),
                  isUsable(key) else { return nil }
            return uncompressedPublicKey(from: key.publicKey.rawRepresentation)
        }
    }

    // MARK: - Private helper

    // A key can reconstruct successfully from its stored data (well-formed wrapped blob) while
    // still being unusable, e.g. after the device was erased and restored from a backup: the
    // wrapping is tied to the Secure Enclave's state at generation time, so an old blob can parse
    // fine and still fail the moment the enclave actually tries to use it. Reconstruction alone
    // can't tell the two apart, so this exercises the same signing path `signMessage` uses.
    private static let usabilityCheckPayload = Data([0x00])

    private func isUsable(_ key: SecureEnclave.P256.Signing.PrivateKey) -> Bool {
        (try? key.signature(for: Self.usabilityCheckPayload)) != nil
    }

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
