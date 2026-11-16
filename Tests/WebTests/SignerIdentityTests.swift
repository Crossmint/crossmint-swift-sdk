//
//  SignerIdentityTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 16/11/26.
//

import Testing
@testable import Web

@Suite("Signer Identity", .tags(.unit))
struct SignerIdentityTests {
    @Test(arguments: [
        (SignerIdentity.email("alice@example.com"), "email"),
        (SignerIdentity.phone("+15551234567", channel: nil), "phone")
    ])
    func logsOnlyTheKindOfIdentity(identity: SignerIdentity, expected: String) {
        #expect(identity.logValue == expected)
    }
}
