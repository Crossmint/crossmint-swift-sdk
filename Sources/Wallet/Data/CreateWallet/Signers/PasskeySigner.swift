import BigInt
import CrossmintCommonTypes
import CryptoKit
import Foundation
import Passkeys

actor PasskeySignerState {
    var adminSigner: PasskeySignerData!

    var isInitialized: Bool {
        adminSigner != nil
    }

    func initialize(adminSigner: PasskeySignerData) async {
        self.adminSigner = adminSigner
    }

    func initialize(
        credentialOptions: PasskeyCredentialCreationOptions,
        name: String
    ) async throws(SignerError) {
        guard !isInitialized else { return }

        do {
            let passkey = Passkey()
            let response = try await passkey.create(
                credentialOptions,
                forcePlatformKey: false,
                forceSecurityKey: false
            )

            switch response {
            case .create(let createResponse):
                guard let publicKeyResponse = createResponse.response.publicKey else {
                    throw SignerError.signingFailed
                }
                self.adminSigner = PasskeySignerData(
                    id: createResponse.id.toBase64URLEncodedString(),
                    name: name,
                    publicKey: .init(x: publicKeyResponse.x, y: publicKeyResponse.y)
                )
            case .get:
                throw SignerError.signingFailed
            }
        } catch {
            throw convertToSignerError(error: error)
        }
    }

    func updateAdminSigner(adminSigner: PasskeySignerData) {
        self.adminSigner = adminSigner
    }
}

public final class PasskeySigner: Signer {
    public typealias AdminType = PasskeySignerData

    public nonisolated let signerType: SignerType = .passkey

    private let defaultCreationChallenge: String = "0xf631058a3ba1116acce12396fad0a125b5041c43f8e15723709f81aa8d5f4ccf"

    private let state = PasskeySignerState()
    private let credentialOptions: PasskeyCredentialCreationOptions

    private let name: String
    private let host: String

    public var adminSigner: PasskeySignerData {
        get async {
            await state.adminSigner
        }
    }

    public init(name: String, host: String) {
        // swiftlint:disable:next force_unwrapping
        let preparedChallenge = defaultCreationChallenge.hexData!.base64EncodedString()
        self.credentialOptions = PasskeyCredentialCreationOptions(
            rp: .init(name: host),
            user: .init(name: name),
            challenge: preparedChallenge,
            pubKeyCredParams: [
                .init(type: "public-key", alg: -7),
                .init(type: "public-key", alg: -257)
            ],
            authenticatorSelection: .init(
                authenticatorAttachment: .platform,
                requireResidentKey: true,
                residentKey: .required,
                userVerification: .required
            ),
            attestation: AttestationConveyancePreference.none
        )
        self.name = name
        self.host = host
    }

    public func initialize(_ service: SmartWalletService?) async throws(SignerError) {
        if await state.isInitialized {
            return
        }

        try await state.initialize(credentialOptions: credentialOptions, name: name)
    }

    public func sign(message: String) async throws(SignerError) -> String {
        guard let preparedChallenge = message.hexData else {
            throw .invalidMessage
        }

        do {
            let passkey = Passkey()
            let response = try await passkey.get(
                PasskeyCredentialRequestOptions(challenge: preparedChallenge, rpId: host),
                forcePlatformKey: false,
                forceSecurityKey: false
            )

            switch response {
            case .create:
                throw SignerError.signingFailed
            case .get(let getResponse):
                return getResponse.json()
            }
        } catch {
            throw convertToSignerError(error: error)
        }
    }

    public func approvals(
        withSignature signature: String
    ) async throws(SignerError) -> [SignRequestApi.Approval] {
        let jsonData = Data(signature.utf8)
        let authResponse: AuthenticationResponseJSON
        do {
            authResponse = try JSONDecoder().decode(AuthenticationResponseJSON.self, from: jsonData)
        } catch {
            throw .signingFailed
        }

        let response = authResponse.response
        guard let signature = parseAsn1Signature(response.signature) else {
            throw SignerError.signingFailed
        }

        let passkeySignature = SignRequestApi.Approval.PasskeySignature(
            r: String(signature.r),
            s: String(signature.s)
        )

        guard let clientDataJSON = String(data: response.clientDataJSON, encoding: .utf8) else {
            throw .signingFailed
        }

        let passkeyMetadata = SignRequestApi.Approval.PasskeyMetadata(
            authenticatorData: response.authenticatorData.toHexString(withPrefix: true),
            clientDataJSON: clientDataJSON
        )

        // Return the approval
        return [
            .passkey(
                signer: await adminSigner.locator,
                signature: passkeySignature,
                metadata: passkeyMetadata
            )
        ]
    }

    public func updateAdminSigner(_ adminSigner: PasskeySignerData) async -> any Signer {
        await state.updateAdminSigner(adminSigner: adminSigner)
        return self
    }

    private func parseAsn1Signature(_ signature: Data) -> (r: String, s: String)? {
        // Ensure the signature is at least long enough for ASN.1 structure
        guard signature.count >= 8 else { return nil }

        var offset = 0

        // Expecting 0x30 (SEQUENCE)
        guard signature[offset] == 0x30 else { return nil }
        offset += 1

        // Skip total length byte
        offset += 1

        // Expecting 0x02 (INTEGER for r)
        guard signature[offset] == 0x02 else { return nil }
        offset += 1

        let rLength = Int(signature[offset])
        offset += 1

        let rBytes = signature[offset..<offset + rLength]
        offset += rLength

        // Expecting 0x02 (INTEGER for s)
        guard signature[offset] == 0x02 else { return nil }
        offset += 1

        let sLength = Int(signature[offset])
        offset += 1

        let sBytes = signature[offset..<offset + sLength]

        let r = BigUInt(rBytes)
        let sRaw = BigUInt(sBytes)

        guard let n = BigUInt(
            "FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551",
            radix: 16
        ) else { return nil }

        let s = sRaw > n / 2 ? n - sRaw : sRaw

        // Convert to hex strings padded to 64 characters (32 bytes), and prefix with "0x"
        func paddedHex(_ value: BigUInt) -> String {
            let hex = value.serialize().map { String(format: "%02x", $0) }.joined()
            let padded = String(repeating: "0", count: max(64 - hex.count, 0)) + hex
            return "0x" + padded
        }

        return (r: paddedHex(r), s: paddedHex(s))
    }
}

private func convertToSignerError(error: Error) -> SignerError {
    let errorCode = (error as NSError).code
    switch errorCode {
    case 1001:
        return .passkey(.cancelled)
    case 1004:
        return .passkey(.requestFailed)
    case 4004:
        return .passkey(.badConfiguration)
    case 31:
        return .passkey(.timedOut)
    default:
        return .passkey(.unknown)
    }
}
