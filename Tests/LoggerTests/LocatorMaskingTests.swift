//
//  LocatorMaskingTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 11/11/26.
//

@testable import Logger
import Testing

@Suite("Locator masking", .tags(.unit))
struct LocatorMaskingTests {
    @Test(arguments: [
        ("email:alice@example.com", "email:a***@example.com"),
        ("email:josé@exämple.com", "email:j***@exämple.com"),
        ("email:\"john doe\"@example.com", "email:\"***@example.com"),
        ("email:alice@example.com:base", "email:a***@example.com:base"),
        ("email:not-an-email", "email:***"),
        ("email:", "email:***"),
        ("phone:+15551234567", "phone:+1***4567"),
        ("phone:+1 (555) 123 45 67", "phone:+1***4567"),
        ("phoneNumber:+447700900123:polygon", "phoneNumber:+4***0123:polygon"),
        ("phone:1234", "phone:***")
    ])
    func masksEmailAndPhoneLocators(locator: String, expected: String) {
        #expect(LogMask.locator(locator) == expected)
    }

    @Test(arguments: [
        "device:MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE",
        "external-wallet:0x8f3a1c2b4d5e6f708192a3b4c5d6e7f8",
        "passkey:credential-id",
        "api-key",
        "quorum:q-1",
        "0x8f3a1c2b4d5e6f708192a3b4c5d6e7f8"
    ])
    func leavesOtherLocatorsIntact(locator: String) {
        #expect(LogMask.locator(locator) == locator)
    }
}
