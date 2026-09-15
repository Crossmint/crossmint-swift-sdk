//
//  SignerTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 15/09/26.
//

import Testing

@testable import Wallet

@Suite("Signer", .tags(.unit))
struct SignerTests {
    @Test func derivesItsLocatorFromTheAdminSigner() async {
        let signer = MockSigner(email: "user@example.com")

        #expect(await signer.locator == .email("user@example.com"))
    }

    @Test func approvesWithItsOwnSignature() async throws {
        let signer = MockSigner(email: "user@example.com")
        signer.approvalsResult = [.keypair(signer: "email:user@example.com", signature: "mock-signature")]

        let approvals = try await signer.approvals(for: "bWVzc2FnZQ==")

        guard case let .keypair(locator, signature) = try #require(approvals.first) else {
            Issue.record("Expected a keypair approval")
            return
        }
        #expect(locator == "email:user@example.com")
        #expect(signature == "mock-signature")
    }
}
