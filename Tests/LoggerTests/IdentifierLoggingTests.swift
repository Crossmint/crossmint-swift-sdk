//
//  IdentifierLoggingTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 16/11/26.
//

@testable import Logger
import Testing

@Suite("Identifiers in log attributes", .tags(.unit))
struct IdentifierLoggingTests {
    @Test(arguments: [
        ("email:alice@example.com", "email:***"),
        ("email:alice@example.com:base", "email:***:base"),
        ("phone:+15551234567", "phone:***"),
        ("phoneNumber:+15551234567:base", "phoneNumber:***:base"),
        ("twitter:alice_example", "twitter:***"),
        ("twitter:alice_example:base", "twitter:***:base"),
        ("x:alice_example", "x:***"),
        ("userId:user-8f3a1c2b", "userId:***")
    ])
    func emitsNoPartOfAPersonalIdentifier(identifier: String, expected: String) throws {
        let provider = MockLoggerProvider()

        Logger(testProviders: [provider]).info("wallet.signer.start", attributes: ["locator": identifier])

        let logged = try #require(provider.lastAttributes?["locator"] as? String)
        #expect(logged == expected)
    }

    @Test(arguments: [
        "device:04a1b2c3d4e5f60718293a4b5c6d7e8f",
        "external-wallet:0x8f3a1c2b4d5e6f708192a3b4c5d6e7f8a9b0c1d2",
        "base:0x8f3a1c2b4d5e6f708192a3b4c5d6e7f8a9b0c1d2",
        "me:evm"
    ])
    func keepsIdentifiersThatAreNotPersonal(identifier: String) throws {
        let provider = MockLoggerProvider()

        Logger(testProviders: [provider]).info("wallet.signer.start", attributes: ["locator": identifier])

        let logged = try #require(provider.lastAttributes?["locator"] as? String)
        #expect(logged == identifier)
    }
}
