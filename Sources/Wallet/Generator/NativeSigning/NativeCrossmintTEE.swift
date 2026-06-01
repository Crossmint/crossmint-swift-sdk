import CryptoKit
import DeviceSigner
import Foundation
import Utils
import Web

// Concrete NativeSigningDelegate implementation using SE/Keychain crypto.
//
// Usage (after CrossmintSDK.configure):
//   CrossmintSDK.shared.enableNativeSigning()
//
// That call sets CrossmintTEE.shared?.nativeSigningDelegate = DefaultNativeSigningDelegate(...)
// which reroutes signTransaction through native HPKE onboarding + local key derivation + signing.
public final class DefaultNativeSigningDelegate: NativeSigningDelegate, @unchecked Sendable {
    private let identityKey = DeviceIdentityKey.shared
    private let apiClient: NativeTEEClient

    // Temporary storage for the TEE public key between start and complete onboarding.
    // Keyed by signerID. Cleared after completeOnboarding succeeds.
    private var pendingTEEKeys = [String: String]()

    public init(apiKey: String, isProduction: Bool) {
        apiClient = NativeTEEClient(
            baseURL: isProduction
                // swiftlint:disable:next force_unwrapping
                ? URL(string: "https://signers.crossmint.com")!
                // swiftlint:disable:next force_unwrapping
                : URL(string: "https://staging.signers.crossmint.com")!,
            apiKey: apiKey
        )
    }

    // MARK: - NativeSigningDelegate

    public func hasOnboarded(forSignerID signerID: String) -> Bool {
        MasterSecretStore.exists(forSignerID: signerID)
    }

    // Calls the TEE API to send an OTP email to the user.
    // Stores the TEE's P-256 pubkey for use in completeOnboarding.
    // TODO(server): TEE must accept `native: true` flag to skip FPE and return teePublicKey.
    public func startOnboarding(signerID: String, authID: String) async throws {
        let privKey  = try identityKey.get()
        let deviceID = try identityKey.deviceID
        let pubB64   = privKey.publicKey.x963Representation.base64EncodedString()

        let resp = try await apiClient.startOnboarding(
            deviceID: deviceID, signerID: signerID, authID: authID, devicePubKeyBase64: pubB64
        )
        guard let teeKey = resp.teePublicKey else { throw NativeError.missingTEEPublicKey }
        pendingTEEKeys[signerID] = teeKey
    }

    // HPKE-seals the OTP to the TEE; receives HPKE-sealed master secret in return.
    public func completeOnboarding(signerID: String, otp: String) async throws {
        guard let teeKeyB64 = pendingTEEKeys[signerID],
              let teeKeyData = Data(base64Encoded: teeKeyB64) else {
            throw NativeError.missingTEEPublicKey
        }
        let teePubKey = try P256.KeyAgreement.PublicKey(x963Representation: teeKeyData)
        let privKey   = try identityKey.get()
        let deviceID  = try identityKey.deviceID

        // Seal {deviceId, otp} to the TEE — only the TEE can open this.
        let payload = try JSONEncoder().encode(["deviceId": deviceID, "otp": otp])
        let sealed  = try HPKEPrimitives.seal(plaintext: payload, recipientPublicKey: teePubKey)

        let completeResp = try await apiClient.completeOnboarding(
            deviceID: deviceID,
            signerID: signerID,
            enc: sealed.enc.base64EncodedString(),
            ciphertext: sealed.ciphertext.base64EncodedString()
        )
        guard let ems = completeResp.encryptedMasterSecret,
              let enc = Data(base64Encoded: ems.encapsulatedKey),
              let ct  = Data(base64Encoded: ems.ciphertext) else {
            throw NativeError.onboardingFailed
        }

        // Decap inside the SE — the scalar multiplication never leaves the enclave.
        let masterSecret = try HPKEPrimitives.openSE(enc: enc, ciphertext: ct, recipientPrivateKey: privKey)
        guard masterSecret.count == 32 else { throw NativeError.invalidMasterSecret }

        try MasterSecretStore.save(masterSecret, forSignerID: signerID)
        pendingTEEKeys.removeValue(forKey: signerID)
    }

    // Derives the blockchain key from master secret and signs locally. No network call.
    public func sign(signerID: String, transaction: String, keyType: String, encoding: String) async throws -> String {
        guard let masterSecret = MasterSecretStore.load(forSignerID: signerID) else {
            throw NativeError.masterSecretMissing
        }
        let messageBytes = try decode(transaction, encoding: encoding)
        switch keyType {
        case "secp256k1":
            // Returns "0x" + r(32) + s(32) + v(1) — matches open-signer output format.
            return try Secp256k1Derivation.sign(message: messageBytes, masterSecret: masterSecret)
        case "ed25519":
            let sig = try MasterSecretDerivation.signEd25519(message: messageBytes, masterSecret: masterSecret)
            return encode(sig, encoding: encoding)
        default:
            throw NativeError.unsupportedKeyType(keyType)
        }
    }

    // MARK: - Private

    private func decode(_ s: String, encoding: String) throws -> Data {
        switch encoding {
        case "hex":
            let bare = s.hasPrefix("0x") ? String(s.dropFirst(2)) : s
            guard let d = Data(hexString: bare) else { throw NativeError.invalidMessage }
            return d
        case "base64":
            guard let d = Data(base64Encoded: s) else { throw NativeError.invalidMessage }
            return d
        case "base58":
            do { return try Base58.decode(s, padTo32: false) } catch { throw NativeError.invalidMessage }
        default:
            throw NativeError.unsupportedEncoding(encoding)
        }
    }

    private func encode(_ data: Data, encoding: String) -> String {
        switch encoding {
        case "hex":    return data.map { String(format: "%02hhx", $0) }.joined()
        case "base64": return data.base64EncodedString()
        case "base58": return (try? Base58.encode(data)) ?? data.base64EncodedString()
        default:       return data.base64EncodedString()
        }
    }

    private enum NativeError: Error {
        case missingTEEPublicKey
        case onboardingFailed
        case invalidMasterSecret
        case masterSecretMissing
        case invalidMessage
        case unsupportedKeyType(String)
        case unsupportedEncoding(String)
    }
}

// MARK: - Hex helper

private extension Data {
    init?(hexString: String) {
        guard hexString.count % 2 == 0 else { return nil }
        var bytes = [UInt8]()
        var idx = hexString.startIndex
        while idx < hexString.endIndex {
            let next = hexString.index(idx, offsetBy: 2)
            guard let byte = UInt8(hexString[idx..<next], radix: 16) else { return nil }
            bytes.append(byte); idx = next
        }
        self = Data(bytes)
    }
}
