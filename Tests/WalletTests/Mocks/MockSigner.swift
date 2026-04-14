import CrossmintCommonTypes
@testable import Wallet

final class MockSigner: Signer, @unchecked Sendable {
    typealias AdminType = EmailSignerData

    var signerType: SignerType { .email }
    var adminSigner: EmailSignerData { EmailSignerData(email: "mock@example.com") }

    var initializeCallCount = 0
    var signResult: String = "mock-signature"
    var approvalsResult: [SignRequestApi.Approval] = []

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
