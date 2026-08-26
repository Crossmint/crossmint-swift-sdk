import CrossmintCommonTypes
import Web

/// A phone (SMS or WhatsApp) OTP signer.
///
/// One class covers every chain because all three differ only in the key type, the signature
/// encoding, and whether the message carries a hex prefix.
public final class PhoneSigner: EmailSigner, Sendable {
    public typealias AdminType = PhoneSignerData

    let crossmintTEE: CrossmintTEE?
    private let chainType: ChainType

    /// In E.164 format, e.g. `"+15551234567"`.
    public let phone: String
    public let channel: OTPDeliveryChannel?

    var identity: SignerIdentity { .phone(phone, channel: channel) }

    public var adminSigner: PhoneSignerData {
        get async {
            PhoneSignerData(phone: phone)
        }
    }

    public var keyType: String {
        get async {
            switch chainType {
            case .evm, .unknown: "secp256k1"
            case .solana, .stellar: "ed25519"
            }
        }
    }

    public var encoding: String {
        get async {
            switch chainType {
            case .evm, .unknown: "hex"
            case .solana: "base58"
            case .stellar: "base64"
            }
        }
    }

    nonisolated public let signerType: SignerType = .phone

    public init(phone: String, channel: OTPDeliveryChannel?, chainType: ChainType, crossmintTEE: CrossmintTEE?) {
        self.crossmintTEE = crossmintTEE
        self.chainType = chainType
        self.phone = phone
        self.channel = channel
    }

    func processMessage(_ message: String) -> String {
        switch chainType {
        case .evm, .unknown: message.noHexPrefix
        case .solana, .stellar: message
        }
    }
}
