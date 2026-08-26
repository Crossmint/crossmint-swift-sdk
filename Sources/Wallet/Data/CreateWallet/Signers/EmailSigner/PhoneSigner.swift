import CrossmintCommonTypes
import Foundation
import Web

/// A phone (SMS or WhatsApp) OTP signer.
///
/// One class covers every chain because all three differ only in the key type, the signature
/// encoding, and whether the message carries a hex prefix.
public final class PhoneSigner: EmailSigner, Sendable {
    public typealias AdminType = PhoneSignerData

    let crossmintTEE: CrossmintTEE?
    let identity: SignerIdentity
    private let chainType: ChainType

    public var adminSigner: PhoneSignerData {
        get async {
            PhoneSignerData(phone: phone ?? "")
        }
    }

    public var keyType: String {
        get async {
            chainType == .evm || chainType == .unknown ? "secp256k1" : "ed25519"
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

    public var phone: String? {
        guard case .phone(let number, _) = identity else { return nil }
        return number
    }

    public var channel: OTPDeliveryChannel? {
        identity.channel
    }

    nonisolated public let signerType: SignerType = .phone

    public init(phone: String, channel: OTPDeliveryChannel?, chainType: ChainType, crossmintTEE: CrossmintTEE?) {
        self.crossmintTEE = crossmintTEE
        self.chainType = chainType
        self.identity = .phone(phone, channel: channel)
    }

    func processMessage(_ message: String) -> String {
        chainType == .evm || chainType == .unknown ? message.noHexPrefix : message
    }
}
