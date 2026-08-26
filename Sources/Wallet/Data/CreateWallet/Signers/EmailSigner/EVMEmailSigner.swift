import CrossmintCommonTypes
import Web

public final class EVMEmailSigner: EmailSigner, Sendable {
    public typealias AdminType = EmailSignerData

    let crossmintTEE: CrossmintTEE?
    public let email: String

    var identity: SignerIdentity { .email(email) }

    public var adminSigner: EmailSignerData {
        get async {
            EmailSignerData(email: email)
        }
    }

    public var keyType: String {
        get async {
            "secp256k1"
        }
    }

    public var encoding: String {
        get async {
            "hex"
        }
    }

    nonisolated public let signerType: SignerType = .email

    public init(email: String, crossmintTEE: CrossmintTEE?) {
        self.crossmintTEE = crossmintTEE
        self.email = email
    }

    func processMessage(_ message: String) -> String {
        message.noHexPrefix
    }
}
