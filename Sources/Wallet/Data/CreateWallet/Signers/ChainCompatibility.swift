import CrossmintCommonTypes
import Foundation
import Web

public protocol EVMCompatibleSigner: Sendable {}
public protocol SolanaCompatibleSigner: Sendable {}
public protocol StellarCompatibleSigner: Sendable {}

public enum EVMSigners: Sendable, SignerProvider {
    case email(String)
    case phone(String, channel: OTPDeliveryChannel? = nil)
    case apiKey
    case passkey(name: String, host: String)

    @MainActor
    public var signer: any Signer {
        switch self {
        case .apiKey:
            ApiKeySigner(adminSigner: ApiKeySignerData())
        case let .email(email):
            EVMEmailSigner(email: email, crossmintTEE: CrossmintTEE.shared)
        case let .phone(phone, channel):
            PhoneSigner(phone: phone, channel: channel, chainType: .evm, crossmintTEE: CrossmintTEE.shared)
        case let .passkey(name, host):
            PasskeySigner(name: name, host: host)
        }
    }
}

public enum SolanaSigners: Sendable, SignerProvider {
    case email(String)
    case phone(String, channel: OTPDeliveryChannel? = nil)
    case apiKey

    @MainActor
    public var signer: any Signer {
        switch self {
        case .apiKey:
            ApiKeySigner(adminSigner: ApiKeySignerData())
        case let .email(email):
            SolanaEmailSigner(email: email, crossmintTEE: CrossmintTEE.shared)
        case let .phone(phone, channel):
            PhoneSigner(phone: phone, channel: channel, chainType: .solana, crossmintTEE: CrossmintTEE.shared)
        }
    }
}

public enum StellarSigners: Sendable, SignerProvider {
    case email(String)
    case phone(String, channel: OTPDeliveryChannel? = nil)
    case apiKey

    @MainActor
    public var signer: any Signer {
        switch self {
        case .apiKey:
            ApiKeySigner(adminSigner: ApiKeySignerData())
        case let .email(email):
            StellarEmailSigner(email: email, crossmintTEE: CrossmintTEE.shared)
        case let .phone(phone, channel):
            PhoneSigner(phone: phone, channel: channel, chainType: .stellar, crossmintTEE: CrossmintTEE.shared)
        }
    }
}
