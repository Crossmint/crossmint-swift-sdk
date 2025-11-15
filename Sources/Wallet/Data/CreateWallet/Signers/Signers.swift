@available(*, deprecated, message: "Use EVMSigners or SolanaSigners for type-safe chain compatibility")
public enum Signers: Sendable {
    case solanaEmailSigner
    case evmEmailSigner
    case solanaFireblocksSigner
    case evmFireblocksSigner
    case passkeySigner(name: String, host: String)

    @MainActor
    public var signer: any Signer {
        switch self {
        case .evmFireblocksSigner:
            EVMApiKeySigner()
        case .solanaFireblocksSigner:
            SolanaApiKeySigner()
        case .solanaEmailSigner:
            SolanaEmailSigner(crossmintTEE: CrossmintTEE.shared)
        case .evmEmailSigner:
            EVMEmailSigner(crossmintTEE: CrossmintTEE.shared)
        case let .passkeySigner(name, host):
            PasskeySigner(name: name, host: host)
        }
    }
}
