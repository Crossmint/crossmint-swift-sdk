import Foundation
import Web

public protocol EVMCompatibleSigner: Sendable {}
public protocol SolanaCompatibleSigner: Sendable {}
public protocol StellarCompatibleSigner: Sendable {}

public enum EVMSigners: Sendable {
    case email(String)
    case apiKey
    case passkey(name: String, host: String)

    @MainActor
    public var signer: any Signer {
        switch self {
        case .apiKey:
            EVMApiKeySigner()
        case let .email(email):
            EVMEmailSigner(email: email, crossmintTEE: CrossmintTEE.shared)
        case let .passkey(name, host):
            PasskeySigner(name: name, host: host)
        }
    }
}

public enum SolanaSigners: Sendable {
    case email(String)
    case apiKey

    @MainActor
    public var signer: any Signer {
        switch self {
        case .apiKey:
            SolanaApiKeySigner()
        case let .email(email):
            SolanaEmailSigner(email: email, crossmintTEE: CrossmintTEE.shared)
        }
    }
}

public enum StellarSigners: Sendable {
    case email(String)
    case apiKey

    @MainActor
    public var signer: any Signer {
        switch self {
        case .apiKey:
            StellarApiKeySigner()
        case let .email(email):
            StellarEmailSigner(email: email, crossmintTEE: CrossmintTEE.shared)
        }
    }
}
