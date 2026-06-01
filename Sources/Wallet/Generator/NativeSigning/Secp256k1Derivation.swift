import CryptoKit
import Foundation
import P256K
import libsecp256k1

// Derives an EVM secp256k1 signing key from the TEE master secret and produces
// Ethereum-compatible recoverable ECDSA signatures.
//
// Derivation matches open-signer:
//   SHA256(master_secret || "secp256k1-derivation-path"), retry if scalar is invalid.
// Signing matches open-signer:
//   sign(SHA256(message), lowS: true) → "0x" || r(32) || s(32) || v(1)  where v ∈ {0x1b, 0x1c}
enum Secp256k1Derivation {

    // MARK: - Key derivation

    // Returns a P256K.Signing.PrivateKey from a 32-byte master secret.
    static func privateKey(from masterSecret: Data) throws -> P256K.Signing.PrivateKey {
        let scalar = derivedScalar(from: masterSecret)
        return try P256K.Signing.PrivateKey(dataRepresentation: Array(scalar), format: .uncompressed)
    }

    // Returns the 33-byte compressed public key (02/03 || x) for display or registration.
    static func compressedPublicKey(from masterSecret: Data) throws -> Data {
        let key = try privateKey(from: masterSecret)
        return key.publicKey.dataRepresentation
    }

    // MARK: - Signing

    // Signs the SHA-256 hash of `message` with the key derived from `masterSecret`.
    // Returns "0x" + r(32 bytes hex) + s(32 bytes hex) + v(1 byte hex), matching open-signer output.
    static func sign(message: Data, masterSecret: Data) throws -> String {
        let digest = Array(SHA256.hash(data: message))
        let scalar = Array(derivedScalar(from: masterSecret))
        return try signHash(digest: digest, privateKeyBytes: scalar)
    }

    // Signs a pre-hashed 32-byte digest directly (for callers that already hash externally).
    static func signHash(digest: Data, masterSecret: Data) throws -> String {
        try signHash(digest: Array(digest), privateKeyBytes: Array(derivedScalar(from: masterSecret)))
    }

    // MARK: - Private

    // Derives the 32-byte secp256k1 private key scalar from the master secret.
    // Matches open-signer: SHA256(master_secret || "secp256k1-derivation-path"), retry if invalid.
    private static func derivedScalar(from masterSecret: Data) -> Data {
        let label = Data("secp256k1-derivation-path".utf8)
        var input = masterSecret
        input.append(label)
        var candidate = Data(SHA256.hash(data: input))
        while !isValidScalar(candidate) {
            candidate = Data(SHA256.hash(data: candidate))
        }
        return candidate
    }

    // secp256k1 group order n. A valid scalar is in [1, n-1].
    private static let secp256k1Order = Data([
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE,
        0xBA, 0xAE, 0xDC, 0xE6, 0xAF, 0x48, 0xA0, 0x3B,
        0xBF, 0xD2, 0x5E, 0x8C, 0xD0, 0x36, 0x41, 0x41,
    ])

    private static func isValidScalar(_ bytes: Data) -> Bool {
        guard bytes.count == 32, bytes.contains(where: { $0 != 0 }) else { return false }
        return bytes.lexicographicallyPrecedes(secp256k1Order)
    }

    // Produces a recoverable ECDSA signature, matching EVMKeyPairSigner.rawSign.
    private static func signHash(digest: [UInt8], privateKeyBytes: [UInt8]) throws -> String {
        guard let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY)) else {
            throw SigningError.contextCreationFailed
        }
        defer { secp256k1_context_destroy(context) }

        let sigPtr = UnsafeMutablePointer<secp256k1_ecdsa_recoverable_signature>.allocate(capacity: 1)
        defer { sigPtr.deallocate() }

        var mutableDigest = digest
        guard secp256k1_ecdsa_sign_recoverable(context, sigPtr, &mutableDigest, privateKeyBytes, nil, nil) == 1 else {
            throw SigningError.signingFailed
        }

        var compact = [UInt8](repeating: 0, count: 64)
        var recid: Int32 = 0
        secp256k1_ecdsa_recoverable_signature_serialize_compact(context, &compact, &recid, sigPtr)

        // Ethereum encodes recovery id as 27 or 28 (not 0 or 1).
        let v = UInt(recid) + 27
        let r = Data(compact[0..<32]).hexString
        let s = Data(compact[32..<64]).hexString
        return "0x\(r)\(s)\(String(v, radix: 16, uppercase: false))"
    }

    enum SigningError: Error {
        case contextCreationFailed
        case signingFailed
    }
}

// MARK: - Data hex helper (local to this file, avoids import of Utils)

private extension Data {
    var hexString: String {
        map { String(format: "%02hhx", $0) }.joined()
    }
}
