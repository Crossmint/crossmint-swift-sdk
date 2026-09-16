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
    /// The device signer key could not sign. The ``DeviceSignerError`` gives the cause.
    case device(DeviceSignerError)
}

/// A signer that can approve a transaction or a signature request.
/// Every ``Signer`` is an `ApprovalSigner`. The device signer conforms to this protocol only.
public protocol ApprovalSigner: Sendable {
    /// The locator that the Crossmint API uses for this signer.
    /// `nil` when the signer does not have a locator yet, for example a device signer with no key.
    var locator: SignerLocator? { get async }

    /// Makes the signer ready to approve through `service`. A signer with no setup step does nothing.
    func initialize(_ service: SmartWalletService?) async throws(SignerError)

    /// Signs `message`. Returns the approvals to send for this message.
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
    public var locator: SignerLocator? {
        get async { SignerLocator(orUnknown: await adminSigner.locator) }
    }

    public func approvals(for message: String) async throws(SignerError) -> [SignRequestApi.Approval] {
        try await approvals(withSignature: try await sign(message: message))
    }
}

extension ApprovalSigner {
    public func initialize() async throws(SignerError) {
        try await initialize(nil)
    }
}
