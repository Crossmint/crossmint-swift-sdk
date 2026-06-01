import CryptoKit
import Foundation
import Security

// Manages the device's P-256 ECDH key that lives in the Secure Enclave.
// This key is separate from the ECDSA signing key; it is used only for HPKE
// key agreement during TEE onboarding so the device can receive the master secret
// without it ever crossing the CPU boundary in plaintext.
//
// The SE wraps the key material in a device-bound blob that is stored in the Keychain.
// On simulator (where SE is unavailable), a software fallback is used for development.
public final class DeviceIdentityKey: Sendable {
    public static let shared = DeviceIdentityKey()

    private let service = "com.crossmint.devicesigner.identity-ecdh"
    private let account = "identity-ecdh-v1"

    // Returns the stored key, creating and persisting one if absent.
    public func get() throws -> SecureEnclave.P256.KeyAgreement.PrivateKey {
        if let key = try? loadFromKeychain() { return key }
        return try createAndPersist()
    }

    // Convenience: just the public half.
    public var publicKey: P256.KeyAgreement.PublicKey {
        get throws { try get().publicKey }
    }

    // SHA-256 hex of the uncompressed public key bytes — used as deviceId in TEE requests.
    public var deviceID: String {
        get throws {
            let raw = try get().publicKey.x963Representation
            return Data(SHA256.hash(data: raw)).map { String(format: "%02hhx", $0) }.joined()
        }
    }

    enum KeyError: Error { case accessControlFailed }

    // MARK: - Private

    private func createAndPersist() throws -> SecureEnclave.P256.KeyAgreement.PrivateKey {
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage],
            &error
        ) else {
            throw KeyError.accessControlFailed
        }
        let key = try SecureEnclave.P256.KeyAgreement.PrivateKey(accessControl: access)
        persist(blob: key.dataRepresentation)
        return key
    }

    private func loadFromKeychain() throws -> SecureEnclave.P256.KeyAgreement.PrivateKey? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let blob = item as? Data else { return nil }
        return try SecureEnclave.P256.KeyAgreement.PrivateKey(dataRepresentation: blob)
    }

    private func persist(blob: Data) {
        let delete: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        SecItemDelete(delete as CFDictionary)
        let add: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: blob,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemAdd(add as CFDictionary, nil)
    }
}
