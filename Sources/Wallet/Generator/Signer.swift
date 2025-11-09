import CrossmintCommonTypes

public enum SignerType: String, Encodable, Sendable {
    case externalWallet = "external-wallet"
    case passkey
    case apiKey = "api-key"
    case email
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
}

public protocol Signer<AdminType>: Sendable {
    associatedtype AdminType: AdminSignerData

    var signerType: SignerType { get }
    var adminSigner: AdminType { get async }

    func initialize(_ service: SmartWalletService?) async throws(SignerError)

    func sign(
        message: String
    ) async throws(SignerError) -> String

    func approvals(
        withSignature signature: String
    ) async throws(SignerError) -> [SignRequestApi.Approval]
}

extension Signer {
    public func initialize() async throws(SignerError) {
        try await initialize(nil)
    }
}
