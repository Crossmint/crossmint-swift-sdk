import CrossmintCommonTypes
import DeviceSigner

public enum SignerType: String, Encodable, Sendable {
    case externalWallet = "external-wallet"
    case passkey
    case apiKey = "api-key"
    case email
    case phone
}

public enum SignerError: Error, Equatable {
    public enum PasskeyError: Error, Equatable {
        case notSupported
        case requestFailed
        case cancelled
        case invalidChallenge
        case invalidUser
        case badConfiguration
        case timedOut
        /// The authenticator returned an assertion without verifying the user (no biometrics or
        /// PIN). The on-chain verifier requires user verification and rejects such assertions.
        case userVerificationMissing
        case unknown
    }
    case invalidPrivateKey
    case invalidAddress
    case invalidMessage
    case signingFailed
    case notStarted
    case invalidSigner
    case invalidEmail
    case passkey(PasskeyError)
    case cancelled
    /// The device signer key on this device could not sign. See ``DeviceSignerError`` for the cause.
    case device(DeviceSignerError)
}

/// A signer that can approve a Crossmint transaction or signature request.
///
/// Every ``Signer`` is an `ApprovalSigner`. Signers that are never the wallet's admin signer, such
/// as the device signer, conform to this protocol only.
public protocol ApprovalSigner: Sendable {
    /// The locator the Crossmint API uses for this signer, e.g. `"email:user@example.com"` or
    /// `"device:<pubkey>"`. `nil` when the locator is not known yet, such as a device signer with
    /// no key on this device.
    var locator: String? { get async }

    func initialize(_ service: SmartWalletService?) async throws(SignerError)

    /// Signs `message` and returns the approval entries to submit for it.
    func approvals(for message: String) async throws(SignerError) -> [SignRequestApi.Approval]
}

public protocol Signer<AdminType>: ApprovalSigner {
    associatedtype AdminType: AdminSignerData

    var signerType: SignerType { get }
    var adminSigner: AdminType { get async }

    func sign(
        message: String
    ) async throws(SignerError) -> String

    func approvals(
        withSignature signature: String
    ) async throws(SignerError) -> [SignRequestApi.Approval]
}

extension Signer {
    public var locator: String? {
        get async {
            await adminSigner.locator
        }
    }

    public func approvals(for message: String) async throws(SignerError) -> [SignRequestApi.Approval] {
        let signature = try await sign(message: message)
        return try await approvals(withSignature: signature)
    }
}

extension ApprovalSigner {
    public func initialize() async throws(SignerError) {
        try await initialize(nil)
    }
}
