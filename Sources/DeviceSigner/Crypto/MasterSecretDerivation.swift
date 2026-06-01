import CryptoKit
import Foundation

// Derives blockchain signing keys from the 32-byte master secret returned by the TEE.
// Derivation logic must match open-signer's shared/cryptography exactly so that the
// same master secret produces the same public key on both sides.
enum MasterSecretDerivation {

    // MARK: - Ed25519 (Solana, Stellar)

    // JS: first 32 bytes of master_secret are used directly as the Ed25519 seed.
    // Reference: open-signer/shared/cryptography/src/algorithms/asymmetric/ed25519.ts
    static func ed25519PrivateKey(from masterSecret: Data) throws -> Curve25519.Signing.PrivateKey {
        guard masterSecret.count >= 32 else { throw DerivationError.invalidMasterSecret }
        return try Curve25519.Signing.PrivateKey(rawRepresentation: masterSecret.prefix(32))
    }

    // Sign message bytes with the Ed25519 key derived from master secret.
    // Returns the raw 64-byte signature.
    static func signEd25519(message: Data, masterSecret: Data) throws -> Data {
        let key = try ed25519PrivateKey(from: masterSecret)
        return try Data(key.signature(for: message))
    }

    // MARK: - Secp256k1 (EVM) — key bytes only; signing is in Secp256k1Derivation (Wallet target)

    // JS: SHA256(master_secret || "secp256k1-derivation-path"), retry if invalid scalar.
    // Reference: open-signer/shared/cryptography/src/algorithms/asymmetric/secp256k1.ts
    static func secp256k1PrivateKeyBytes(from masterSecret: Data) -> Data {
        let label = Data("secp256k1-derivation-path".utf8)
        var input = masterSecret
        input.append(label)
        var candidate = Data(SHA256.hash(data: input))
        while !isValidSecp256k1Scalar(candidate) {
            candidate = Data(SHA256.hash(data: candidate))
        }
        return candidate
    }

    // MARK: - Errors

    enum DerivationError: Error {
        case invalidMasterSecret
    }

    // MARK: - Private

    // Secp256k1 group order n (big-endian). A valid private key is in [1, n-1].
    private static let secp256k1Order = Data([
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE,
        0xBA, 0xAE, 0xDC, 0xE6, 0xAF, 0x48, 0xA0, 0x3B,
        0xBF, 0xD2, 0x5E, 0x8C, 0xD0, 0x36, 0x41, 0x41,
    ])

    private static func isValidSecp256k1Scalar(_ bytes: Data) -> Bool {
        guard bytes.count == 32, bytes.contains(where: { $0 != 0 }) else { return false }
        return bytes.lexicographicallyPrecedes(secp256k1Order)
    }
}
