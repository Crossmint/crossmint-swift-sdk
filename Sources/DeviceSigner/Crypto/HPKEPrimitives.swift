import CryptoKit
import Foundation

// RFC 9180 HPKE — suite DHKEM(P-256, HKDF-SHA256) / HKDF-SHA256 / AES-256-GCM.
// This is the suite used by open-signer for device ↔ TEE communication.
//
// Only base mode (no PSK, no sender auth) is implemented; that is all the TEE
// protocol requires for the device recipient path.
//
// HKDF is implemented directly over HMAC<SHA256> to avoid reliance on the
// CryptoKit HKDF.extract/expand interface which is not available on all iOS 15 builds.
enum HPKEPrimitives {

    // MARK: - Suite IDs (RFC 9180 §5)

    // "KEM" || I2OSP(0x0010, 2) — DHKEM(P-256, HKDF-SHA256)
    static let kemSuiteID  = Data([0x4B, 0x45, 0x4D, 0x00, 0x10])

    // "HPKE" || I2OSP(KEM=0x0010,2) || I2OSP(KDF=0x0001,2) || I2OSP(AEAD=0x0002,2)
    static let hpkeSuiteID = Data([0x48, 0x50, 0x4B, 0x45, 0x00, 0x10, 0x00, 0x01, 0x00, 0x02])

    // MARK: - HKDF-SHA256 primitives (RFC 5869)

    // Extract: PRK = HMAC-SHA256(salt, IKM). Empty or nil salt → 32 zero bytes per RFC 5869 §2.2.
    private static func hkdfExtract(salt: Data?, ikm: Data) -> Data {
        let saltKey: SymmetricKey
        if let s = salt, !s.isEmpty {
            saltKey = SymmetricKey(data: s)
        } else {
            saltKey = SymmetricKey(data: Data(repeating: 0, count: 32))
        }
        return Data(HMAC<SHA256>.authenticationCode(for: ikm, using: saltKey))
    }

    // Expand: T(i) = HMAC-SHA256(PRK, T(i-1) || info || i)
    private static func hkdfExpand(prk: Data, info: Data, length: Int) -> Data {
        let prkKey = SymmetricKey(data: prk)
        var output = Data()
        var prev   = Data()
        var counter: UInt8 = 1
        while output.count < length {
            var input = prev
            input.append(info)
            input.append(counter)
            let t = Data(HMAC<SHA256>.authenticationCode(for: input, using: prkKey))
            output.append(contentsOf: t)
            prev = t
            counter += 1
        }
        return Data(output.prefix(length))
    }

    // MARK: - Labeled HKDF (RFC 9180 §4)

    // LabeledExtract(salt, label, ikm, suite_id):
    //   labeled_ikm = "HPKE-v1" || suite_id || label || ikm
    //   return Extract(salt, labeled_ikm)
    static func labeledExtract(salt: Data?, label: String, ikm: Data, suiteID: Data) -> Data {
        var labeled = Data("HPKE-v1".utf8)
        labeled.append(suiteID)
        labeled.append(Data(label.utf8))
        labeled.append(ikm)
        return hkdfExtract(salt: salt, ikm: labeled)
    }

    // LabeledExpand(prk, label, info, L, suite_id):
    //   labeled_info = I2OSP(L, 2) || "HPKE-v1" || suite_id || label || info
    //   return Expand(prk, labeled_info, L)
    static func labeledExpand(prk: Data, label: String, info: Data, length: Int, suiteID: Data) -> Data {
        var labeled = Data()
        labeled.append(UInt8((length >> 8) & 0xFF))
        labeled.append(UInt8(length & 0xFF))
        labeled.append(Data("HPKE-v1".utf8))
        labeled.append(suiteID)
        labeled.append(Data(label.utf8))
        labeled.append(info)
        return hkdfExpand(prk: prk, info: labeled, length: length)
    }

    // MARK: - DHKEM(P-256, HKDF-SHA256) §4.1

    struct EncapResult {
        /// 65-byte uncompressed serialization of the ephemeral public key (sent to recipient).
        let enc: Data
        /// 32-byte KEM shared secret (drives the HPKE key schedule).
        let sharedSecret: Data
    }

    // DH output + kem_context → 32-byte shared secret.
    private static func extractAndExpand(dh: Data, kemContext: Data) -> Data {
        let prk = labeledExtract(salt: nil, label: "eae_prk", ikm: dh, suiteID: kemSuiteID)
        return labeledExpand(prk: prk, label: "shared_secret", info: kemContext, length: 32, suiteID: kemSuiteID)
    }

    // Encap: generate ephemeral key, ECDH with recipient.
    static func encap(recipientPublicKey: P256.KeyAgreement.PublicKey) throws -> EncapResult {
        let ephemeral = P256.KeyAgreement.PrivateKey()
        let dh = try ephemeral.sharedSecretFromKeyAgreement(with: recipientPublicKey)
            .withUnsafeBytes { Data($0) }
        let enc = ephemeral.publicKey.x963Representation // 04 || x || y, 65 bytes
        var kemContext = enc
        kemContext.append(recipientPublicKey.x963Representation)
        return EncapResult(enc: enc, sharedSecret: extractAndExpand(dh: dh, kemContext: kemContext))
    }

    // Decap with an in-memory P-256 key.
    static func decap(enc: Data, recipientPrivateKey: P256.KeyAgreement.PrivateKey) throws -> Data {
        let pkE = try P256.KeyAgreement.PublicKey(x963Representation: enc) // validates on-curve
        let dh = try recipientPrivateKey.sharedSecretFromKeyAgreement(with: pkE)
            .withUnsafeBytes { Data($0) }
        var kemContext = enc
        kemContext.append(recipientPrivateKey.publicKey.x963Representation)
        return extractAndExpand(dh: dh, kemContext: kemContext)
    }

    // Decap with a Secure Enclave key — the scalar multiplication stays inside the SE.
    static func decapSE(enc: Data, recipientPrivateKey: SecureEnclave.P256.KeyAgreement.PrivateKey) throws -> Data {
        let pkE = try P256.KeyAgreement.PublicKey(x963Representation: enc)
        let dh = try recipientPrivateKey.sharedSecretFromKeyAgreement(with: pkE)
            .withUnsafeBytes { Data($0) }
        var kemContext = enc
        kemContext.append(recipientPrivateKey.publicKey.x963Representation)
        return extractAndExpand(dh: dh, kemContext: kemContext)
    }

    // MARK: - Key Schedule (RFC 9180 §5.1, base mode)

    private struct KeySchedule {
        let key: SymmetricKey // 32-byte AES-256 key
        let baseNonce: Data   // 12-byte GCM nonce (sequence number 0)
    }

    private static func keySchedule(sharedSecret: Data, info: Data) -> KeySchedule {
        // Base mode: psk = "", psk_id = ""
        let pskIDHash = labeledExtract(salt: nil, label: "psk_id_hash", ikm: Data(), suiteID: hpkeSuiteID)
        let infoHash = labeledExtract(salt: nil, label: "info_hash", ikm: info, suiteID: hpkeSuiteID)

        var ksContext = Data([0x00]) // mode_base = 0
        ksContext.append(pskIDHash)
        ksContext.append(infoHash)

        let prk = labeledExtract(salt: sharedSecret, label: "secret", ikm: Data(), suiteID: hpkeSuiteID)
        let keyBytes = labeledExpand(prk: prk, label: "key", info: ksContext, length: 32, suiteID: hpkeSuiteID)
        let nonceData = labeledExpand(prk: prk, label: "base_nonce", info: ksContext, length: 12, suiteID: hpkeSuiteID)

        return KeySchedule(key: SymmetricKey(data: keyBytes), baseNonce: nonceData)
    }

    // MARK: - Seal / Open (single-shot, sequence number 0)

    struct SealResult {
        /// 65-byte encapsulated key to transmit to the recipient alongside the ciphertext.
        let enc: Data
        /// AES-256-GCM ciphertext concatenated with the 16-byte authentication tag.
        let ciphertext: Data
    }

    enum HPKEError: Error {
        case ciphertextTooShort
    }

    static func seal(
        plaintext: Data,
        recipientPublicKey: P256.KeyAgreement.PublicKey,
        info: Data = Data(),
        aad: Data = Data()
    ) throws -> SealResult {
        let r = try encap(recipientPublicKey: recipientPublicKey)
        let ks = keySchedule(sharedSecret: r.sharedSecret, info: info)
        let nonce = try AES.GCM.Nonce(data: ks.baseNonce)
        let box = try AES.GCM.seal(plaintext, using: ks.key, nonce: nonce, authenticating: aad)
        var ct = box.ciphertext
        ct.append(box.tag)
        return SealResult(enc: r.enc, ciphertext: ct)
    }

    static func open(
        enc: Data,
        ciphertext: Data,
        recipientPrivateKey: P256.KeyAgreement.PrivateKey,
        info: Data = Data(),
        aad: Data = Data()
    ) throws -> Data {
        let sharedSecret = try decap(enc: enc, recipientPrivateKey: recipientPrivateKey)
        return try openInner(sharedSecret: sharedSecret, ciphertext: ciphertext, info: info, aad: aad)
    }

    static func openSE(
        enc: Data,
        ciphertext: Data,
        recipientPrivateKey: SecureEnclave.P256.KeyAgreement.PrivateKey,
        info: Data = Data(),
        aad: Data = Data()
    ) throws -> Data {
        let sharedSecret = try decapSE(enc: enc, recipientPrivateKey: recipientPrivateKey)
        return try openInner(sharedSecret: sharedSecret, ciphertext: ciphertext, info: info, aad: aad)
    }

    private static func openInner(sharedSecret: Data, ciphertext: Data, info: Data, aad: Data) throws -> Data {
        guard ciphertext.count >= 16 else { throw HPKEError.ciphertextTooShort }
        let ks = keySchedule(sharedSecret: sharedSecret, info: info)
        let nonce = try AES.GCM.Nonce(data: ks.baseNonce)
        let ct  = ciphertext.prefix(ciphertext.count - 16)
        let tag = ciphertext.suffix(16)
        let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ct, tag: tag)
        return try AES.GCM.open(box, using: ks.key, authenticating: aad)
    }
}
