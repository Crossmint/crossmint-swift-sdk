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
    /// A quorum that approves only when `threshold` of its `members` approve.
    /// A member cannot be a quorum or an API key signer.
    indirect case quorum(threshold: Int, members: [EVMSigners])

    @MainActor
    public var signer: any Signer {
        switch self {
        case let .quorum(threshold, members):
            QuorumSigner(threshold: threshold, members: members.map(\.signer))
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

/// The recovery signers for a Solana wallet.
///
/// A passkey cannot be a recovery signer on Solana.
/// To add a passkey to a Solana wallet, use ``Wallet/addSigner(_:)`` with ``SignerConfig/passkey(name:host:id:)``.
public enum SolanaSigners: Sendable, SignerProvider {
    case email(String)
    case phone(String, channel: OTPDeliveryChannel? = nil)
    case apiKey
    /// A quorum that approves only when `threshold` of its `members` approve.
    /// A member cannot be a quorum or an API key signer.
    indirect case quorum(threshold: Int, members: [SolanaSigners])

    @MainActor
    public var signer: any Signer {
        switch self {
        case let .quorum(threshold, members):
            QuorumSigner(threshold: threshold, members: members.map(\.signer))
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
    case passkey(name: String, host: String)
    /// A quorum that approves only when `threshold` of its `members` approve.
    /// A member cannot be a quorum or an API key signer.
    indirect case quorum(threshold: Int, members: [StellarSigners])

    @MainActor
    public var signer: any Signer {
        switch self {
        case let .quorum(threshold, members):
            QuorumSigner(threshold: threshold, members: members.map(\.signer))
        case .apiKey:
            ApiKeySigner(adminSigner: ApiKeySignerData())
        case let .email(email):
            StellarEmailSigner(email: email, crossmintTEE: CrossmintTEE.shared)
        case let .phone(phone, channel):
            PhoneSigner(phone: phone, channel: channel, chainType: .stellar, crossmintTEE: CrossmintTEE.shared)
        case let .passkey(name, host):
            PasskeySigner(name: name, host: host)
        }
    }
}
