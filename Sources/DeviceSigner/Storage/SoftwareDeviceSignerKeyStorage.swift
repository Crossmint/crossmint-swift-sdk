//
//  SoftwareDeviceSignerKeyStorage.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 3/3/26.
//


import CryptoKit
import Foundation

/// A ``DeviceSignerKeyStorage`` implementation using software P-256 keys stored in the Keychain.
///
/// This implementation is intended for use on **simulators only**. Keys are stored as raw key
/// material in the Keychain rather than in dedicated hardware, providing no hardware-backed isolation.
///
/// On physical devices that lack a Secure Enclave, the device signer feature should not be used.
/// Use an alternative signer (e.g., email or passkey) instead.
///
/// - Important: Do not ship this implementation to production. ``DefaultCrossmintWallets`` selects
///   ``SecureEnclaveKeyStorage`` on real devices and falls back to this implementation only
///   when ``SecureEnclave/isAvailable`` returns `false`.
public final class SoftwareDeviceSignerKeyStorage: DeviceSignerKeyStorage {
    public init() {}

    public func isAvailable() async -> Bool {
        true
    }

    public func generateKey(address: String?) async throws(DeviceSignerError) -> String {
        let key = P256.Signing.PrivateKey()
        let rawPublicKey = key.publicKey.rawRepresentation  // 64 bytes: x‖y
        let publicKeyBase64 = rawPublicKey.base64EncodedString()

        let tag: String
        if let address {
            tag = "crossmint.device.wallet.\(address)"
        } else {
            tag = "crossmint.device.pending.\(publicKeyBase64)"
        }

        // Store the 32-byte private key scalar
        try DeviceSignerKeychainStorage.save(key.rawRepresentation, tag: tag)

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
              let key = try? P256.Signing.PrivateKey(rawRepresentation: keyData) else {
            return nil
        }
        return key.publicKey.rawRepresentation.base64EncodedString()
    }

    public func signMessage(
        address: String,
        message: String
    ) async throws(DeviceSignerError) -> (r: String, s: String) {
        let tag = "crossmint.device.wallet.\(address)"
        guard let keyData = DeviceSignerKeychainStorage.load(tag: tag),
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
        try DeviceSignerKeychainStorage.delete(tag: tag)
    }

    // MARK: - Private helpers

    private func hexString<D: DataProtocol>(from data: D) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}
