import CrossmintCommonTypes

public class ApiKeySigner: Signer, @unchecked Sendable {
    public let adminSigner: ApiKeySignerData

    public typealias AdminType = ApiKeySignerData
    nonisolated public let signerType: SignerType = .apiKey

    init(adminSigner: ApiKeySignerData = ApiKeySignerData()) {
        self.adminSigner = adminSigner
    }

    public func initialize(_ service: SmartWalletService?) async throws(SignerError) {
        // Nothing to do here.
    }

    public func sign(
        message: String
    ) async throws(SignerError) -> String {
        throw .signingFailed
    }

    public func approvals(
        withSignature signature: String
    ) async throws(SignerError) -> [SignRequestApi.Approval] {
        throw .signingFailed
    }
}
