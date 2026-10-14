import CrossmintCommonTypes
@testable import Wallet

final class MockSigner: Signer, @unchecked Sendable {
    typealias AdminType = EmailSignerData

    let signerType: SignerType
    var adminSigner: EmailSignerData { EmailSignerData(email: email) }

    private let email: String
    var initializeCallCount = 0
    var signLastMessage: String?
    var signResult: String = "mock-signature"
    var approvalsResult: [SignRequestApi.Approval] = []

    init(email: String = "mock@example.com", signerType: SignerType = .email) {
        self.email = email
        self.signerType = signerType
    }

    func initialize(_ service: SmartWalletService?) async throws(SignerError) {
        initializeCallCount += 1
    }

    func sign(message: String) async throws(SignerError) -> String {
        signLastMessage = message
        return signResult
    }

    func approvals(withSignature signature: String) async throws(SignerError) -> [SignRequestApi.Approval] {
        approvalsResult
    }
}
