import CrossmintCommonTypes
@testable import Wallet

final class MockPasskeySigner: Signer, @unchecked Sendable {
    typealias AdminType = PasskeySignerData

    let signerType: SignerType = .passkey
    let adminSigner: PasskeySignerData

    var initializeCallCount = 0
    var signCallCount = 0
    var signLastMessage: String?
    var signResult = "mock-assertion"

    init(credentialId: String = "mock-credential-id") {
        adminSigner = PasskeySignerData(
            id: credentialId,
            name: "mock-passkey",
            publicKey: .init(
                x: "63974445517478826529511626494808493056716472585867467274057723945542198688292",
                y: "65992374220708497472363050084829585264656015540354474091056129332958175065018"
            )
        )
    }

    func initialize(_ service: SmartWalletService?) async throws(SignerError) {
        initializeCallCount += 1
    }

    func sign(message: String) async throws(SignerError) -> String {
        signCallCount += 1
        signLastMessage = message
        return signResult
    }

    func approvals(withSignature signature: String) async throws(SignerError) -> [SignRequestApi.Approval] {
        []
    }
}
