import CrossmintCommonTypes
import Foundation

public final class EVMEmailSigner: EmailSigner, Sendable {
    public typealias AdminType = EmailSignerData

    private let state = EmailSignerState()
    let crossmintTEE: CrossmintTEE?

    public var adminSigner: EmailSignerData {
        get async {
            guard let email = await state.email else {
                return EmailSignerData(email: "")
            }
            return EmailSignerData(email: email)
        }
    }

    // Hardcoded for EVM
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

    public init(crossmintTEE: CrossmintTEE?) {
        self.crossmintTEE = crossmintTEE
    }

    public func initialize(_ service: SmartWalletService?) async throws(SignerError) {
        guard await !state.isInitialized else { return }

        guard let email = await service?.email else {
            throw SignerError.invalidEmail
        }

        await state.update(email: email)
    }

    func processMessage(_ message: String) -> String {
        message.noHexPrefix
    }
}
