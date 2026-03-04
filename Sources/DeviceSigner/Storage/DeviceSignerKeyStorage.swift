//
//  DeviceSignerKeyStorage.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 3/3/26.
//

import Security

/// Storage abstraction for device signer keys.
///
/// Implementations manage the full lifecycle of a P-256 signing key tied to a wallet address:
/// generation, retrieval, signing, and deletion. Two implementations are provided:
/// - ``SecureEnclaveKeyStorage``: hardware-backed, for physical devices with Secure Enclave.
/// - ``SoftwareDeviceSignerKeyStorage``: software fallback for simulators and older devices.
public protocol DeviceSignerKeyStorage: Sendable {
    /// Returns `true` if this storage backend is available on the current device.
    func isAvailable() async -> Bool

    /// Generates a new P-256 signing key and stores it in the Keychain.
    ///
    /// - Parameter address: The wallet address to associate the key with.
    ///   Pass `nil` when the address is not yet known (e.g., before wallet creation).
    ///   Call ``mapAddressToKey(address:publicKeyBase64:)`` once the address is available.
    /// - Returns: The raw 64-byte public key (x‖y) encoded as a base64 string.
    func generateKey(address: String?) async throws(DeviceSignerError) -> String

    /// Associates a previously generated pending key with a wallet address.
    ///
    /// Call this after wallet creation to rename the Keychain item from the pending tag
    /// to the wallet-address tag.
    ///
    /// - Parameters:
    ///   - address: The on-chain wallet address.
    ///   - publicKeyBase64: The base64-encoded public key returned by ``generateKey(address:)``.
    func mapAddressToKey(address: String, publicKeyBase64: String) async throws(DeviceSignerError)

    /// Returns the base64-encoded public key for the given wallet address, or `nil` if not found.
    func getKey(address: String) async -> String?

    /// Signs a base64-encoded message using the key for the given wallet address.
    ///
    /// - Parameters:
    ///   - address: The wallet address whose key should be used.
    ///   - message: The message to sign, base64-encoded.
    /// - Returns: The ECDSA signature components as hex strings prefixed with `"0x"`.
    func signMessage(
        address: String,
        message: String
    ) async throws(DeviceSignerError) -> (r: String, s: String)

    /// Deletes the signing key for the given wallet address from the Keychain.
    func deleteKey(address: String) async throws(DeviceSignerError)
}
