import Web

public enum NonCustodialSignerError: Error {
    case nonAvailable
    case teeNotStarted
    case generic(String)

    var errorDescription: String {
        switch self {
        case .nonAvailable:
            "Non-Custodial signers system is not available."
        case .generic(let message):
            message
        case .teeNotStarted:
            "Non-Custodial signer is not started"
        }
    }
}

/// Renamed when phone signers joined email signers behind the same protocol. Removable in the
/// next major: no app-reachable API can throw it, since `load()` is capped to internal.
@available(*, deprecated, renamed: "NonCustodialSignerError")
public typealias EmailSignerError = NonCustodialSignerError

protocol NonCustodialSigner: Signer {
    var crossmintTEE: CrossmintTEE? { get }
    var keyType: String { get async }
    var encoding: String { get async }
    var identity: SignerIdentity { get }

    func load() async throws(NonCustodialSignerError)
    func processMessage(_ message: String) -> String
}

extension NonCustodialSigner {
    @MainActor
    public func sign(message: String) async throws(SignerError) -> String {
        guard let crossmintTEE = crossmintTEE else { throw .notStarted }
        do {
            return try await crossmintTEE.signTransaction(
                transaction: processMessage(message),
                keyType: keyType,
                encoding: encoding,
                identity: identity
            )
        } catch CrossmintTEE.Error.userCancelled {
            throw .cancelled
        } catch {
            throw .signingFailed
        }
    }

    public func approvals(
        withSignature signature: String
    ) async throws(SignerError) -> [SignRequestApi.Approval] {
        [.keypair(signer: await adminSigner.locator, signature: signature)]
    }

    public func load() async throws(NonCustodialSignerError) {
        guard let crossmintTEE = crossmintTEE else { throw .teeNotStarted }
        do {
            try await crossmintTEE.load()
        } catch {
            if error == .urlNotAvailable {
                throw .nonAvailable
            }
            throw .generic(error.localizedDescription)
        }
    }

    func processMessage(_ message: String) -> String {
        message
    }

    public func initialize(_ service: SmartWalletService?) async throws(SignerError) {}
}
