import CrossmintCommonTypes
import Web

public final class StellarEmailSigner: NonCustodialSigner, Sendable {
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
            "ed25519"
        }
    }

    public var encoding: String {
        get async {
            "base64"
        }
    }

    nonisolated public let signerType: SignerType = .email

    public init(email: String, crossmintTEE: CrossmintTEE?) {
        self.crossmintTEE = crossmintTEE
        self.email = email
    }
}
