import CryptoKit
import Foundation
import secp256k1

public struct Secp256k1PublicKey: Sendable, Equatable {
    public let bytes: String
    public let encoding: KeyEncoding
    public let keyType: String = "secp256k1"

    public init(bytes: String, encoding: KeyEncoding) {
        self.bytes = bytes
        self.encoding = encoding
    }
}

public struct Secp256k1Signature: Sendable, Equatable {
    public let bytes: String
    public let encoding: KeyEncoding
    public let keyType: String = "secp256k1"

    public init(bytes: String, encoding: KeyEncoding) {
        self.bytes = bytes
        self.encoding = encoding
    }
}

public enum Secp256k1Error: Error, Equatable {
    case invalidSeedLength(Int)
    case invalidPrivateKey
    case invalidDigestLength(Int)
    case signingFailed
    case encodingFailed
}

public struct Secp256k1Strategy: Sendable {
    private static let derivationPath: [UInt8] = [
        0x73, 0x65, 0x63, 0x70, 0x32, 0x35, 0x36, 0x6B, 0x31, 0x2D, 0x64, 0x65,
        0x72, 0x69, 0x76, 0x61, 0x74, 0x69, 0x6F, 0x6E, 0x2D, 0x70, 0x61, 0x74,
        0x68
    ]

    public init() {}

    /// Derive a private key from a seed using secp256k1 derivation.
    /// The seed is concatenated with the derivation path and hashed with SHA-256.
    /// If the resulting key is invalid, the process is repeated recursively.
    public func getPrivateKeyFromSeed(seed: Data) async throws -> Data {
        var derivationSeed = Data(seed)
        derivationSeed.append(contentsOf: Self.derivationPath)

        let privateKeyData = Data(SHA256.hash(data: derivationSeed))

        if isValidPrivateKey(privateKeyData) {
            return privateKeyData
        }

        return try await getPrivateKeyFromSeed(seed: privateKeyData)
    }

    /// Check if a private key is valid for secp256k1.
    private func isValidPrivateKey(_ keyData: Data) -> Bool {
        guard keyData.count == 32 else { return false }

        do {
            _ = try secp256k1.Signing.PrivateKey(dataRepresentation: keyData, format: .uncompressed)
            return true
        } catch {
            return false
        }
    }

    /// Get the public key from a private key.
    /// Returns the uncompressed public key (65 bytes).
    public func getPublicKey(privateKey: Data) throws -> Data {
        guard privateKey.count == 32 else {
            throw Secp256k1Error.invalidPrivateKey
        }

        let signingKey: secp256k1.Signing.PrivateKey
        do {
            signingKey = try secp256k1.Signing.PrivateKey(dataRepresentation: privateKey, format: .uncompressed)
        } catch {
            throw Secp256k1Error.invalidPrivateKey
        }

        return signingKey.publicKey.dataRepresentation
    }

    /// Sign a 32-byte digest with a private key using secp256k1.
    /// Returns the signature with recovery bit (r + s + v format, 65 bytes).
    public func sign(privateKey: Data, digest: Data) throws -> Data {
        guard digest.count == 32 else {
            throw Secp256k1Error.invalidDigestLength(digest.count)
        }

        guard privateKey.count == 32 else {
            throw Secp256k1Error.invalidPrivateKey
        }

        let ecdsaMemory = MemoryLayout<secp256k1_ecdsa_recoverable_signature>.size
        guard let ecdsaMemoryStorage = malloc(ecdsaMemory) else {
            throw Secp256k1Error.signingFailed
        }

        let signaturePointer = ecdsaMemoryStorage.assumingMemoryBound(
            to: secp256k1_ecdsa_recoverable_signature.self
        )

        guard let context = secp256k1_context_create(
            UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY)
        ) else {
            free(signaturePointer)
            throw Secp256k1Error.signingFailed
        }

        defer {
            secp256k1_context_destroy(context)
            free(signaturePointer)
        }

        var hash = [UInt8](digest)
        let keyBytes = [UInt8](privateKey)

        guard secp256k1_ecdsa_sign_recoverable(
            context,
            signaturePointer,
            &hash,
            keyBytes,
            nil,
            nil
        ) == 1 else {
            throw Secp256k1Error.signingFailed
        }

        var signature = [UInt8](repeating: 0, count: 64)
        var recid: Int32 = 0

        secp256k1_ecdsa_recoverable_signature_serialize_compact(
            context,
            &signature,
            &recid,
            signaturePointer
        )

        let recoveryByte: UInt8 = recid == 1 ? 0x1C : 0x1B
        var fullSignature = signature
        fullSignature.append(recoveryByte)

        return Data(fullSignature)
    }

    /// Format a public key as hex with 0x prefix.
    public func formatPublicKey(publicKey: Data) -> Secp256k1PublicKey {
        let hexString = "0x" + publicKey.map { String(format: "%02x", $0) }.joined()
        return Secp256k1PublicKey(bytes: hexString, encoding: .hex)
    }

    /// Format a signature as hex with 0x prefix.
    public func formatSignature(signature: Data) -> Secp256k1Signature {
        let hexString = "0x" + signature.map { String(format: "%02x", $0) }.joined()
        return Secp256k1Signature(bytes: hexString, encoding: .hex)
    }
}
