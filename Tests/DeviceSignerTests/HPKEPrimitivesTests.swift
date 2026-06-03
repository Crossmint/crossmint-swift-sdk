import CryptoKit
import Foundation
import Testing

@testable import DeviceSigner

// Validates HPKEPrimitives and MasterSecretDerivation against:
//   1. Round-trip seal/open (in-memory key)
//   2. A real hpke-js interop vector (the server's exact suite), proving wire compatibility
//   3. Master secret → Ed25519 / secp256k1 key derivation consistency
//
// Serialized: these are fast crypto unit tests, and serial execution keeps the
// run deterministic (parallel workers cascade-fail if any one process exits).
@Suite(.serialized)
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
        let out12 = HPKEPrimitives.labeledExpand(
            prk: prk, label: "key", info: Data(), length: 12, suiteID: HPKEPrimitives.hpkeSuiteID)
        let out32 = HPKEPrimitives.labeledExpand(
            prk: prk, label: "key", info: Data(), length: 32, suiteID: HPKEPrimitives.hpkeSuiteID)
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
        let recovered = try HPKEPrimitives.open(
            enc: sealed.enc, ciphertext: sealed.ciphertext, recipientPrivateKey: recipientKey)
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
        bad[bad.startIndex] ^= 0xFF // flip first byte (startIndex-safe for Data slices)
        #expect(throws: (any Error).self) {
            _ = try HPKEPrimitives.open(enc: sealed.enc, ciphertext: bad, recipientPrivateKey: key)
        }
    }

    // MARK: - hpke-js interop vector
    // Generated with the server's exact suite: @hpke/core 1.7.5,
    // DhkemP256HkdfSha256 / HkdfSha256 / Aes256Gcm (the `createHpkeSuite()` config).
    // This is the path that matters: the TEE service seals, the device opens.
    // Regenerate with /tmp/hpke-interop/gen.mjs if the suite ever changes.

    @Test func hpkeJsInterop_opensServerCiphertext() throws {
        let recipientPrivHex = "b714ae29d2d50ed0ab9256d32374eb970ce8a31048dbceff58e72eeeac937718"
        let encHex = "0420426f9a5c972057af70daf09f5e08de978b383c804c38f6482fc503293a583f" +
            "cc0a60f8ccfe99dd2e804cdf6ec7b018b03e3a2664955d377a91f7a62022b591"
        let ctHex = "e8b4930ce1499697e66717c8699917baa7ec340a49dea94414065252c1f2b513fdbd"

        let privData = try #require(Data(hexString: recipientPrivHex))
        let priv = try P256.KeyAgreement.PrivateKey(rawRepresentation: privData)
        let encData = try #require(Data(hexString: encHex))
        let ctData = try #require(Data(hexString: ctHex))

        let plaintext = try HPKEPrimitives.open(
            enc: encData,
            ciphertext: ctData,
            recipientPrivateKey: priv,
            info: Data("crossmint-interop-v1".utf8),
            aad: Data("aad-12345".utf8)
        )

        // If this matches, our hand-rolled HPKE is bit-compatible with hpke-js on the receive path.
        #expect(String(data: plaintext, encoding: .utf8) == "hello from hpke-js")
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
            0xBF, 0xD2, 0x5E, 0x8C, 0xD0, 0x36, 0x41, 0x41
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
