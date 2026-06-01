import CryptoKit
import Foundation

// Thin REST client for the TEE onboarding endpoints.
//
// The server side requires a small change from the current FPE-based flow:
//   - start-onboarding response must include `teePublicKey` (TEE's P-256 pubkey, base64)
//     so the device can HPKE-encrypt the OTP in complete-onboarding.
//   - The OTP sent to the user's email is a plain numeric code (no FPE), because
//     the confidentiality of the OTP is provided by HPKE transport to the TEE.
// TODO(server): coordinate with Max to ship the `native: true` flag in start-onboarding
//   that triggers this code path on the TEE side.
struct NativeTEEClient {
    let baseURL: URL
    let apiKey: String

    // MARK: - Request / Response types

    struct StartRequest: Encodable {
        let deviceId: String
        let signerId: String
        let authId: String
        let encryptionContext: EncryptionContext
        let native: Bool = true

        struct EncryptionContext: Encodable {
            let publicKey: String // base64 uncompressed P-256 pubkey (65 bytes → 88 base64 chars)
        }
    }

    struct StartResponse: Decodable {
        // TEE's P-256 pubkey — device uses this to HPKE-seal the OTP back.
        let teePublicKey: String?
        let signerStatus: String?
        let error: String?
    }

    struct CompleteRequest: Encodable {
        let deviceId: String
        let signerId: String
        // HPKE seal of JSON { "deviceId": "...", "otp": "..." } to TEE pubkey.
        let encapsulatedKey: String // base64 HPKE enc (65-byte ephemeral pubkey)
        let ciphertext: String      // base64 HPKE ciphertext || 16-byte GCM tag
        let native: Bool = true
    }

    struct CompleteResponse: Decodable {
        let encryptedMasterSecret: EncryptedMasterSecret?
        let signerStatus: String?
        let error: String?

        struct EncryptedMasterSecret: Decodable {
            // TEE HPKE-seals the 32-byte master secret back to the device pubkey.
            let encapsulatedKey: String // base64
            let ciphertext: String      // base64
        }
    }

    // MARK: - API calls

    func startOnboarding(deviceID: String, signerID: String, authID: String, devicePubKeyBase64: String) async throws -> StartResponse {
        let body = StartRequest(
            deviceId: deviceID,
            signerId: signerID,
            authId: authID,
            encryptionContext: .init(publicKey: devicePubKeyBase64)
        )
        return try await post(path: "/v1/signers/start-onboarding", body: body)
    }

    func completeOnboarding(deviceID: String, signerID: String, enc: String, ciphertext: String) async throws -> CompleteResponse {
        let body = CompleteRequest(deviceId: deviceID, signerId: signerID, encapsulatedKey: enc, ciphertext: ciphertext)
        return try await post(path: "/v1/signers/complete-onboarding", body: body)
    }

    // MARK: - Private

    private func post<Req: Encodable, Res: Decodable>(path: String, body: Req) async throws -> Res {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw TEEClientError.httpError(http.statusCode, data)
        }
        return try JSONDecoder().decode(Res.self, from: data)
    }

    enum TEEClientError: Error {
        case httpError(Int, Data)
    }
}
