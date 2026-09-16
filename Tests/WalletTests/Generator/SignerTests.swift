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
    private let signer = MockSigner(email: "user@example.com")

    @Test func derivesItsLocatorFromTheAdminSigner() async {
        #expect(await signer.locator == .email("user@example.com"))
    }
}
