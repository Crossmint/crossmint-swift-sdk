//
//  PersonalDataScrubbingTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 06/11/26.
//

import Foundation
@testable import Logger
import Testing

@Suite("Personal data scrubbing", .tags(.unit))
struct PersonalDataScrubbingTests {
    @Test(arguments: [
        (
            #"Native >> Web: {"data":{"data":{"authId":"email:alice@example.com"}},"event":"request:get-status"}"#,
            #"Native >> Web: {"data":{"data":{"authId":"email:***"}},"event":"request:get-status"}"#
        ),
        (
            #"Native >> Web: {"data":{"data":{"authId":"phone:+15551234567"}},"event":"request:sign"}"#,
            #"Native >> Web: {"data":{"data":{"authId":"phone:***"}},"event":"request:sign"}"#
        ),
        (
            "Console[log]: onboarding email:bob.smith+test@mail.example.co.uk",
            "Console[log]: onboarding email:***"
        ),
        (
            "{\n  \"owner\" : \"phoneNumber:+447700900123\",\n  \"email\" : \"carol@example.org\"\n}",
            "{\n  \"owner\" : \"phoneNumber:***\",\n  \"email\" : \"***\"\n}"
        ),
        (
            "{\n  \"phoneNumber\" : \"+15551234567\",\n  \"phone\" : \"5551234567\"\n}",
            "{\n  \"phoneNumber\" : \"***\",\n  \"phone\" : \"***\"\n}"
        ),
        (
            #"{"authId":"email:josé@exämple.com"}"#,
            #"{"authId":"email:***"}"#
        ),
        (
            "Console[log]: onboarding élodie.dupont@société.fr",
            "Console[log]: onboarding ***"
        ),
        (
            "Console[log]: onboarding 用户@例子.广告",
            "Console[log]: onboarding ***"
        ),
        (
            #"{"authId":"phone:+1 (555) 123-4567"}"#,
            #"{"authId":"phone:***"}"#
        ),
        (
            "recipient phoneNumber:555.123.4567:base signed",
            "recipient phoneNumber:***:base signed"
        ),
        (
            #"{"phone" : "+44 7700 900123"}"#,
            #"{"phone" : "***"}"#
        ),
        (
            "phone:+1 555 123 45 67 approved",
            "phone:*** approved"
        ),
        (
            #"{"onboarding.authId":"email:"john doe"@example.com"}"#,
            #"{"onboarding.authId":"email:***"}"#
        )
    ])
    func masksEmailsAndPhoneNumbers(logLine: String, expected: String) {
        #expect(CredentialScrubber.scrub(logLine) == expected)
    }

    @Test func masksEmailsWithSlashesEscapedByJSONEncoder() throws {
        let message = try JSONEncoder().encode(["authId": "email:alice/smith@example.com"])
        let scrubbed = CredentialScrubber.scrub(try #require(String(bytes: message, encoding: .utf8)))

        #expect(scrubbed == #"{"authId":"email:***"}"#)
    }

    @Test(arguments: [
        (
            "📍 URL: https://staging.crossmint.com/api/2025-06-09/wallets/me:evm/signers/email:alice%40example.com",
            "📍 URL: https://staging.crossmint.com/api/2025-06-09/wallets/me:evm/signers/email:***"
        ),
        (
            "📍 URL: https://staging.crossmint.com/api/2025-06-09/wallets/me:evm/signers/phone:%2B14155552671?chain=base",
            "📍 URL: https://staging.crossmint.com/api/2025-06-09/wallets/me:evm/signers/phone:***?chain=base"
        ),
        (
            "📍 URL: https://staging.crossmint.com/api/2025-06-09/wallets/me:evm/signers/phone:%2B1%20%28415%29%20555-2671/approve",
            "📍 URL: https://staging.crossmint.com/api/2025-06-09/wallets/me:evm/signers/phone:***/approve"
        ),
        (
            "📍 URL: https://staging.crossmint.com/api/2025-06-09/wallets/me:evm/signers/email:jos%C3%A9%40ex%C3%A4mple.com",
            "📍 URL: https://staging.crossmint.com/api/2025-06-09/wallets/me:evm/signers/email:***"
        ),
        (
            "📍 URL: https://staging.crossmint.com/api/2025-06-09/wallets/phoneNumber%3A%2B14155552671%3Abase",
            "📍 URL: https://staging.crossmint.com/api/2025-06-09/wallets/phoneNumber%3A***%3Abase"
        ),
        (
            "📍 URL: https://staging.crossmint.com/api/2025-06-09/wallets/twitter%3Aalice_example%3Abase",
            "📍 URL: https://staging.crossmint.com/api/2025-06-09/wallets/twitter%3A***%3Abase"
        ),
        (
            "Console[log]: onboarding alice%2Btest%40example.com done",
            "Console[log]: onboarding *** done"
        )
    ])
    func masksIdentifiersEncodedInURLs(logLine: String, expected: String) {
        #expect(CredentialScrubber.scrub(logLine) == expected)
    }

    @Test(arguments: [
        "📍 URL: https://staging.crossmint.com/api/2025-06-09/wallets/userId%3Auser-8f3a1c2b%3Abase",
        "📍 URL: https://staging.crossmint.com/api/2025-06-09/wallets/me:evm/signers/device:04a1b2c3d4e5f607",
        "📍 URL: https://staging.crossmint.com/api/2025-06-09/wallets/me:evm/signers/external-wallet:0x8f3a1c2b?chain=base",
        "Loaded crossmint-sdk@1.2.3 in the signer frame",
        #"Web >> Native: {"event":"response:sign","data":{"signature":{"bytes":"0x1234abcd"}}}"#,
        "📍 URL: https://staging.crossmint.com/api/2025-06-09/wallets/0x8f3a1c2b4d5e6f708192a3b4c5d6e7f8"
    ])
    func leavesLinesWithoutPersonalDataIntact(logLine: String) {
        #expect(CredentialScrubber.scrub(logLine) == logLine)
    }
}
