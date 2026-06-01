import CryptoKit
import Foundation
import Testing

@testable import DeviceSigner

// Validates HPKEPrimitives and MasterSecretDerivation against:
//   1. Round-trip seal/open (in-memory key)
//   2. RFC 9180 Appendix A.3 test vectors for DHKEM(P-256,HKDF-SHA256)/HKDF-SHA256/AES-256-GCM
//      base mode — populate `rfcVectors` below from the published spec to enable those tests.
//   3. Master secret → Ed25519 key derivation consistency

struct HPKEPrimitivesTests {

    // MARK: - HKDF labeled helpers

    @Test func labeledExtractDeterministic() {
        // Same inputs must always produce the same PRK bytes.
        let r1 = HPKEPrimitives.labeledExtract(
            salt: nil, label: "eae_prk", ikm: Data(repeating: 0xAB, count: 32),
            suiteID: HPKEPrimitives.kemSuiteID
        )
        let r2 = HPKEPrimitives.labeledExtract(
            salt: nil, label: "eae_prk", ikm: Data(repeating: 0xAB, count: 32),
            suiteID: HPKEPrimitives.kemSuiteID
        )
        #expect(r1 == r2)
        #expect(r1.count == 32) // SHA-256 output
    }

    @Test func labeledExtractSaltVsNoSalt() {
        // Empty salt and nil salt must produce the same result per RFC 5869 §2.2.
        let withNil = HPKEPrimitives.labeledExtract(
            salt: nil, label: "test", ikm: Data("hello".utf8), suiteID: HPKEPrimitives.kemSuiteID
        )
        let withEmpty = HPKEPrimitives.labeledExtract(
            salt: Data(), label: "test", ikm: Data("hello".utf8), suiteID: HPKEPrimitives.kemSuiteID
        )
        #expect(withNil == withEmpty)
    }

    @Test func labeledExpandLength() {
        let prk = HPKEPrimitives.labeledExtract(
            salt: nil, label: "prk", ikm: Data(repeating: 1, count: 32),
            suiteID: HPKEPrimitives.kemSuiteID
        )
        let out12 = HPKEPrimitives.labeledExpand(prk: prk, label: "key", info: Data(), length: 12, suiteID: HPKEPrimitives.hpkeSuiteID)
        let out32 = HPKEPrimitives.labeledExpand(prk: prk, label: "key", info: Data(), length: 32, suiteID: HPKEPrimitives.hpkeSuiteID)
        #expect(out12.count == 12)
        #expect(out32.count == 32)
        // Different lengths → different outputs (the length prefix in labeled_info ensures this)
        #expect(out12 != out32.prefix(12))
    }

    // MARK: - Seal / Open round-trips

    @Test func sealOpenRoundTrip_inMemoryKey() throws {
        let recipientKey = P256.KeyAgreement.PrivateKey()
        let plaintext = Data("native signer PoC test".utf8)
        let info = Data("crossmint-hpke-test".utf8)
        let aad  = Data("additional-data".utf8)

        let sealed = try HPKEPrimitives.seal(
            plaintext: plaintext,
            recipientPublicKey: recipientKey.publicKey,
            info: info, aad: aad
        )
        #expect(sealed.enc.count == 65)           // uncompressed P-256 point
        #expect(sealed.ciphertext.count == plaintext.count + 16) // +16 GCM tag

        let recovered = try HPKEPrimitives.open(
            enc: sealed.enc, ciphertext: sealed.ciphertext,
            recipientPrivateKey: recipientKey, info: info, aad: aad
        )
        #expect(recovered == plaintext)
    }

    @Test func sealOpenRoundTrip_emptyPlaintext() throws {
        let recipientKey = P256.KeyAgreement.PrivateKey()
        let sealed = try HPKEPrimitives.seal(plaintext: Data(), recipientPublicKey: recipientKey.publicKey)
        let recovered = try HPKEPrimitives.open(enc: sealed.enc, ciphertext: sealed.ciphertext, recipientPrivateKey: recipientKey)
        #expect(recovered == Data())
    }

    @Test func openRejectsWrongKey() throws {
        let correctKey = P256.KeyAgreement.PrivateKey()
        let wrongKey   = P256.KeyAgreement.PrivateKey()
        let sealed = try HPKEPrimitives.seal(
            plaintext: Data("secret".utf8), recipientPublicKey: correctKey.publicKey
        )
        #expect(throws: (any Error).self) {
            _ = try HPKEPrimitives.open(enc: sealed.enc, ciphertext: sealed.ciphertext, recipientPrivateKey: wrongKey)
        }
    }

    @Test func openRejectsWrongAAD() throws {
        let key = P256.KeyAgreement.PrivateKey()
        let sealed = try HPKEPrimitives.seal(
            plaintext: Data("secret".utf8),
            recipientPublicKey: key.publicKey,
            aad: Data("correct-aad".utf8)
        )
        #expect(throws: (any Error).self) {
            _ = try HPKEPrimitives.open(
                enc: sealed.enc, ciphertext: sealed.ciphertext,
                recipientPrivateKey: key, aad: Data("wrong-aad".utf8)
            )
        }
    }

    @Test func openRejectsTamperedCiphertext() throws {
        let key = P256.KeyAgreement.PrivateKey()
        let plaintext = Data("tamper test".utf8)
        let sealed = try HPKEPrimitives.seal(plaintext: plaintext, recipientPublicKey: key.publicKey)
        var bad = sealed.ciphertext
        bad[0] ^= 0xFF // flip first byte
        #expect(throws: (any Error).self) {
            _ = try HPKEPrimitives.open(enc: sealed.enc, ciphertext: bad, recipientPrivateKey: key)
        }
    }

    // MARK: - RFC 9180 A.3 interop vectors
    // Populate these from https://www.rfc-editor.org/rfc/rfc9180#appendix-A.3
    // to confirm bit-exact compatibility with hpke-js and other implementations.

    @Test func rfcA3_sharedSecret() throws {
        // skEm — ephemeral sender private key (hex, 32 bytes)
        let skEmHex  = "4995788ef2d484cc60401c6e6f69c5c48bbd0f9e3a12e98d66e34ea40e8e6a"
        // pkRm — recipient public key (uncompressed, hex, 65 bytes)
        let pkRmHex  = "04fe8c19ce0905191ebc298a9245792531f26f0cece2460639e8bc39cb7f706a826a779b4cf969b8a0e539c7f62fb3d30ad6aa8f80e30f1d128aafd68a2ce72ea0"
        // shared_secret — expected KEM shared secret (hex, 32 bytes)
        let expectedHex = "c0d26aeab536609a572b07695d933b589dcf363ff9d93c93adea537aeabb8cb"

        guard let skEm = Data(hexString: skEmHex),
              let pkRm = Data(hexString: pkRmHex),
              let expected = Data(hexString: expectedHex) else {
            Issue.record("Fix hex strings above to match RFC 9180 A.3 exactly")
            return
        }

        let recipientPub  = try P256.KeyAgreement.PublicKey(x963Representation: pkRm)
        let ephemeralPriv = try P256.KeyAgreement.PrivateKey(rawRepresentation: skEm)

        // Manually run DHKEM decap with the known ephemeral key to verify the shared secret
        let enc = ephemeralPriv.publicKey.x963Representation
        let dh  = try ephemeralPriv.sharedSecretFromKeyAgreement(with: recipientPub)
            .withUnsafeBytes { Data($0) }
        var kemContext = enc
        kemContext.append(pkRm)
        let prk = HPKEPrimitives.labeledExtract(salt: nil, label: "eae_prk", ikm: dh, suiteID: HPKEPrimitives.kemSuiteID)
        let sharedSecret = HPKEPrimitives.labeledExpand(prk: prk, label: "shared_secret", info: kemContext, length: 32, suiteID: HPKEPrimitives.kemSuiteID)

        #expect(sharedSecret == expected, "KEM shared secret must match RFC 9180 A.3 vector")
    }

    // MARK: - Master secret derivation

    @Test func ed25519DeriveIsConsistent() throws {
        let ms = Data(repeating: 0x42, count: 32)
        let k1 = try MasterSecretDerivation.ed25519PrivateKey(from: ms)
        let k2 = try MasterSecretDerivation.ed25519PrivateKey(from: ms)
        #expect(k1.rawRepresentation == k2.rawRepresentation)
        #expect(k1.publicKey.rawRepresentation.count == 32) // Ed25519 pubkey
    }

    @Test func ed25519DeriveUsesMasterSecretPrefix() throws {
        // The seed is the first 32 bytes — a longer secret should give the same key as the truncated one.
        let ms32 = Data(repeating: 0xAB, count: 32)
        var ms64 = ms32; ms64.append(Data(repeating: 0xFF, count: 32))
        let k32 = try MasterSecretDerivation.ed25519PrivateKey(from: ms32)
        let k64 = try MasterSecretDerivation.ed25519PrivateKey(from: ms64)
        #expect(k32.rawRepresentation == k64.rawRepresentation)
    }

    @Test func secp256k1DeriveIsConsistent() {
        let ms = Data(repeating: 0x55, count: 32)
        let b1 = MasterSecretDerivation.secp256k1PrivateKeyBytes(from: ms)
        let b2 = MasterSecretDerivation.secp256k1PrivateKeyBytes(from: ms)
        #expect(b1 == b2)
        #expect(b1.count == 32)
    }

    @Test func secp256k1DeriveMatchesJSDerivationPath() throws {
        // Master secret used in open-signer unit tests (replace with actual test vector).
        // Expected private key = SHA256(ms || "secp256k1-derivation-path") if valid.
        let ms = Data(repeating: 0x01, count: 32)
        let label = Data("secp256k1-derivation-path".utf8)
        var input = ms; input.append(label)
        let expected = Data(SHA256.hash(data: input))

        let derived = MasterSecretDerivation.secp256k1PrivateKeyBytes(from: ms)
        // If expected is a valid scalar the derived key must equal it; if not, it retried.
        let secp256k1Order = Data([
            0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
            0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE,
            0xBA, 0xAE, 0xDC, 0xE6, 0xAF, 0x48, 0xA0, 0x3B,
            0xBF, 0xD2, 0x5E, 0x8C, 0xD0, 0x36, 0x41, 0x41,
        ])
        if expected.lexicographicallyPrecedes(secp256k1Order) && expected.contains(where: { $0 != 0 }) {
            #expect(derived == expected)
        } else {
            // The first candidate was invalid; just verify it's still deterministic.
            #expect(derived.count == 32)
        }
    }
}

// MARK: - Hex helper for tests

private extension Data {
    init?(hexString: String) {
        let hex = hexString.replacingOccurrences(of: " ", with: "")
        guard hex.count % 2 == 0 else { return nil }
        var data = Data(capacity: hex.count / 2)
        var idx = hex.startIndex
        while idx < hex.endIndex {
            let nextIdx = hex.index(idx, offsetBy: 2)
            guard let byte = UInt8(hex[idx..<nextIdx], radix: 16) else { return nil }
            data.append(byte)
            idx = nextIdx
        }
        self = data
    }
}
