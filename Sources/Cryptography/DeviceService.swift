import CryptoKit
import Foundation

public struct AuthData: Codable, Sendable {
    public let jwt: String
    public let apiKey: String

    public init(jwt: String, apiKey: String) {
        self.jwt = jwt
        self.apiKey = apiKey
    }
}

public enum DeviceServiceError: Error, Equatable {
    case keyGenerationFailed
    case keyStorageFailed
    case keyRetrievalFailed
    case invalidKeyData
    case hashingFailed

    public var errorMessage: String {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate identity keys"
        case .keyStorageFailed:
            return "Failed to store identity keys"
        case .keyRetrievalFailed:
            return "Failed to retrieve identity keys"
        case .invalidKeyData:
            return "Invalid key data"
        case .hashingFailed:
            return "Failed to hash public key"
        }
    }
}

public actor DeviceService {
    private static let identityStorageKey = "crossmint-identity-key"

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func getId() async throws -> String {
        let publicKey = try await getIdentityPublicKey()
        let rawKeyData = publicKey.rawRepresentation
        let hash = SHA256.hash(data: rawKeyData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    public func getSerializedIdentityPublicKey() async throws -> String {
        let publicKey = try await getIdentityPublicKey()
        let rawKeyData = publicKey.rawRepresentation
        return rawKeyData.base64EncodedString()
    }

    public func getIdentityPublicKey() async throws -> P256.KeyAgreement.PublicKey {
        let keyPair = try await getOrCreateIdentityKeys()
        return keyPair.publicKey
    }

    private func getOrCreateIdentityKeys() async throws -> P256.KeyAgreement.PrivateKey {
        if let existingKey = loadStoredKey() {
            return existingKey
        }

        let newKey = P256.KeyAgreement.PrivateKey()
        try storeKey(newKey)
        return newKey
    }

    private func loadStoredKey() -> P256.KeyAgreement.PrivateKey? {
        guard let keyData = userDefaults.data(forKey: Self.identityStorageKey) else {
            return nil
        }

        return try? P256.KeyAgreement.PrivateKey(rawRepresentation: keyData)
    }

    private func storeKey(_ key: P256.KeyAgreement.PrivateKey) throws {
        let keyData = key.rawRepresentation
        userDefaults.set(keyData, forKey: Self.identityStorageKey)
    }

    public func clearIdentityKeys() {
        userDefaults.removeObject(forKey: Self.identityStorageKey)
    }
}
