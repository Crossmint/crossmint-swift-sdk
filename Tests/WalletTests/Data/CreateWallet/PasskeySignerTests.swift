import CrossmintCommonTypes
import Foundation
import Testing
@testable import Wallet

struct PasskeySignerTests {
    // authenticatorData = rpIdHash (32 bytes) + flags + signCount (4 bytes).
    // flags=0x1d: UP + UV + BE + BS.
    private let verifiedAuthenticatorData = "jOWe17+aF5xwGJgCOkFxzFLAsVqRz9oN77NWCcBqWQQdAAAAAQ=="
    // flags=0x19: UP + BE + BS, no UV.
    private let unverifiedAuthenticatorData = "jOWe17+aF5xwGJgCOkFxzFLAsVqRz9oN77NWCcBqWQQZAAAAAQ=="
    private let derSignature =
        "MEQCIBERERERERERERERERERERERERERERERERERERERERERAiAiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIg=="
    private let clientDataJSON =
        "eyJ0eXBlIjoid2ViYXV0aG4uZ2V0IiwiY2hhbGxlbmdlIjoiYWJjIiwib3JpZ2luIjoiaHR0cHM6Ly9leGFtcGxlLmNvbSJ9"

    private func assertion(authenticatorData: String) -> String {
        """
        {"type":"public-key","id":"Y3JlZC1pZA==","rawId":"Y3JlZC1pZA==",\
        "response":{"authenticatorData":"\(authenticatorData)",\
        "clientDataJSON":"\(clientDataJSON)","signature":"\(derSignature)"}}
        """
    }

    private func signer() async -> PasskeySigner {
        let signer = PasskeySigner(name: "alice", host: "example.com")
        _ = await signer.updateAdminSigner(
            PasskeySignerData(id: "cred-id", name: "alice", publicKey: .init(x: "1", y: "2"))
        )
        return signer
    }

    @Test(.tags(.unit))
    func approvalsRejectsAssertionWithoutUserVerification() async throws {
        let signer = await signer()

        await #expect(throws: SignerError.passkey(.userVerificationMissing)) {
            try await signer.approvals(withSignature: assertion(authenticatorData: unverifiedAuthenticatorData))
        }
    }

    @Test(.tags(.unit))
    func approvalsAcceptsUserVerifiedAssertion() async throws {
        let signer = await signer()

        let approvals = try await signer.approvals(
            withSignature: assertion(authenticatorData: verifiedAuthenticatorData)
        )

        #expect(approvals.count == 1)
    }
}
