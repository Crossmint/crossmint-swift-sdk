import Foundation

public protocol EVMCompatibleSigner: Sendable {}
public protocol SolanaCompatibleSigner: Sendable {}

public enum EVMSigners: Sendable {
    case email
    case apiKey
    case passkey(name: String, host: String)

    @MainActor
    public var signer: any Signer {
        switch self {
        case .apiKey:
            EVMApiKeySigner()
        case .email:
            EVMEmailSigner(crossmintTEE: CrossmintTEE.shared)
        case let .passkey(name, host):
            PasskeySigner(name: name, host: host)
        }
    }
}

public enum SolanaSigners: Sendable {
    case email
    case apiKey

    @MainActor
    public var signer: any Signer {
        switch self {
        case .apiKey:
            SolanaApiKeySigner()
        case .email:
            SolanaEmailSigner(crossmintTEE: CrossmintTEE.shared)
        }
    }
}
