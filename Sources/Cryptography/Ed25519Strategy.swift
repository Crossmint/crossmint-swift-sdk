import CryptoKit
import Foundation
import Utils

public enum KeyEncoding: String, Sendable {
    case base58
    case hex
}

public struct Ed25519PublicKey: Sendable, Equatable {
    public let bytes: String
    public let encoding: KeyEncoding
    public let keyType: String = "ed25519"

    public init(bytes: String, encoding: KeyEncoding) {
        self.bytes = bytes
        self.encoding = encoding
    }
}

public struct Ed25519Signature: Sendable, Equatable {
    public let bytes: String
    public let encoding: KeyEncoding
    public let keyType: String = "ed25519"

    public init(bytes: String, encoding: KeyEncoding) {
        self.bytes = bytes
        self.encoding = encoding
    }
}

public enum Ed25519Error: Error, Equatable {
    case invalidSeedLength(Int)
    case invalidKeyLength(Int)
    case signingFailed
    case encodingFailed
}

public struct Ed25519Strategy: Sendable {
    public init() {}

    /// Derive a private key from a seed.
    /// The seed must be at least 32 bytes. Only the first 32 bytes are used.
    /// Returns the 32-byte private key (seed portion).
    public func getPrivateKeyFromSeed(seed: Data) throws -> Data {
        guard seed.count >= 32 else {
            throw Ed25519Error.invalidSeedLength(seed.count)
        }

        let trimmedSeed = seed.prefix(32)
        return Data(trimmedSeed)
    }

    /// Get the public key from a private key.
    /// The private key can be 32 bytes (seed only) or 64 bytes (seed + public key).
    /// Returns the 32-byte public key.
    public func getPublicKey(privateKey: Data) throws -> Data {
        let keyBytes: Data
        if privateKey.count == 64 {
            keyBytes = Data(privateKey.suffix(32))
        } else if privateKey.count == 32 {
            let signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKey)
            keyBytes = signingKey.publicKey.rawRepresentation
        } else {
            throw Ed25519Error.invalidKeyLength(privateKey.count)
        }
        return keyBytes
    }

    /// Sign a message with a private key using Ed25519.
    /// The private key should be 32 bytes (seed).
    /// Returns the 64-byte signature.
    public func sign(privateKey: Data, message: Data) throws -> Data {
        let keyData: Data
        if privateKey.count == 64 {
            keyData = Data(privateKey.prefix(32))
        } else if privateKey.count == 32 {
            keyData = privateKey
        } else {
            throw Ed25519Error.invalidKeyLength(privateKey.count)
        }

        let signingKey: Curve25519.Signing.PrivateKey
        do {
            signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: keyData)
        } catch {
            throw Ed25519Error.signingFailed
        }

        let signature: Data
        do {
            signature = try signingKey.signature(for: message)
        } catch {
            throw Ed25519Error.signingFailed
        }

        return signature
    }

    /// Format a public key with the specified encoding.
    /// Default encoding is base58.
    public func formatPublicKey(
        publicKey: Data,
        encoding: KeyEncoding = .base58
    ) throws -> Ed25519PublicKey {
        let encodedBytes: String
        switch encoding {
        case .base58:
            encodedBytes = try Base58.encode(publicKey)
        case .hex:
            encodedBytes = publicKey.map { String(format: "%02x", $0) }.joined()
        }

        return Ed25519PublicKey(bytes: encodedBytes, encoding: encoding)
    }

    /// Format a signature with the specified encoding.
    /// Default encoding is base58.
    public func formatSignature(
        signature: Data,
        encoding: KeyEncoding = .base58
    ) throws -> Ed25519Signature {
        let encodedBytes: String
        switch encoding {
        case .base58:
            encodedBytes = try Base58.encode(signature)
        case .hex:
            encodedBytes = signature.map { String(format: "%02x", $0) }.joined()
        }

        return Ed25519Signature(bytes: encodedBytes, encoding: encoding)
    }
}
