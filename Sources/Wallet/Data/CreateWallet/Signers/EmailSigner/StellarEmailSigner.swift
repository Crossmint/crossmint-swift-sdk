import CrossmintCommonTypes
import Foundation
import Web

public final class StellarEmailSigner: EmailSigner, Sendable {
    public typealias AdminType = EmailSignerData

    let crossmintTEE: CrossmintTEE?
    let identity: SignerIdentity

    public var adminSigner: EmailSignerData {
        get async {
            EmailSignerData(email: await email ?? "")
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

    public var email: String? {
        get async {
            guard case .email(let address) = identity else { return nil }
            return address
        }
    }

    nonisolated public let signerType: SignerType = .email

    public init(email: String, crossmintTEE: CrossmintTEE?) {
        self.crossmintTEE = crossmintTEE
        self.identity = .email(email)
    }
}
