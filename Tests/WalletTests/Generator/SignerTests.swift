import Testing

@testable import Wallet

@Suite("Signer", .tags(.unit))
struct SignerTests {
    private let signer = MockSigner(email: "user@example.com")

    @Test func derivesItsLocatorFromTheAdminSigner() async {
        #expect(await signer.locator == .email("user@example.com"))
    }

    @Test func approvesWithItsOwnSignature() async throws {
        signer.approvalsResult = [.keypair(signer: "email:user@example.com", signature: "mock-signature")]

        let approvals = try await signer.approvals(for: "bWVzc2FnZQ==")

        #expect(try #require(approvals.first?.keypair) == ("email:user@example.com", "mock-signature"))
    }
}
