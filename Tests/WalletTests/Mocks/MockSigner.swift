import CrossmintCommonTypes
@testable import Wallet

final class MockSigner: Signer, @unchecked Sendable {
    typealias AdminType = EmailSignerData

    var signerType: SignerType { .email }
    var adminSigner: EmailSignerData { EmailSignerData(email: email) }

    private let email: String
    var initializeCallCount = 0
    var signResult: String = "mock-signature"
    var approvalsResult: [SignRequestApi.Approval] = []

    init(email: String = "mock@example.com") {
        self.email = email
    }

    func initialize(_ service: SmartWalletService?) async throws(SignerError) {
        initializeCallCount += 1
    }

    func sign(message: String) async throws(SignerError) -> String {
        signResult
    }

    func approvals(withSignature signature: String) async throws(SignerError) -> [SignRequestApi.Approval] {
        approvalsResult
    }
}
