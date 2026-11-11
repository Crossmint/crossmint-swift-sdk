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
            #"Native >> Web: {"data":{"data":{"authId":"email:a***@example.com"}},"event":"request:get-status"}"#
        ),
        (
            #"Native >> Web: {"data":{"data":{"authId":"phone:+15551234567"}},"event":"request:sign"}"#,
            #"Native >> Web: {"data":{"data":{"authId":"phone:+1***4567"}},"event":"request:sign"}"#
        ),
        (
            "Console[log]: onboarding email:bob.smith+test@mail.example.co.uk",
            "Console[log]: onboarding email:b***@mail.example.co.uk"
        ),
        (
            "{\n  \"owner\" : \"phoneNumber:+447700900123\",\n  \"email\" : \"carol@example.org\"\n}",
            "{\n  \"owner\" : \"phoneNumber:+4***0123\",\n  \"email\" : \"c***@example.org\"\n}"
        ),
        (
            "{\n  \"phoneNumber\" : \"+15551234567\",\n  \"phone\" : \"5551234567\"\n}",
            "{\n  \"phoneNumber\" : \"+1***4567\",\n  \"phone\" : \"5***4567\"\n}"
        ),
        (
            #"{"authId":"email:josé@exämple.com"}"#,
            #"{"authId":"email:j***@exämple.com"}"#
        ),
        (
            "Console[log]: onboarding élodie.dupont@société.fr",
            "Console[log]: onboarding é***@société.fr"
        ),
        (
            "Console[log]: onboarding 用户@例子.广告",
            "Console[log]: onboarding 用***@例子.广告"
        ),
        (
            #"{"authId":"phone:+1 (555) 123-4567"}"#,
            #"{"authId":"phone:+1***4567"}"#
        ),
        (
            "recipient phoneNumber:555.123.4567:base signed",
            "recipient phoneNumber:5***4567:base signed"
        ),
        (
            #"{"phone" : "+44 7700 900123"}"#,
            #"{"phone" : "+4***0123"}"#
        ),
        (
            "phone:+1 555 123 45 67 approved",
            "phone:+1*** approved"
        )
    ])
    func masksEmailsAndPhoneNumbers(logLine: String, expected: String) {
        #expect(CredentialScrubber.scrub(logLine) == expected)
    }

    @Test func masksEmailsWithSlashesEscapedByJSONEncoder() throws {
        let message = try JSONEncoder().encode(["authId": "email:alice/smith@example.com"])
        let scrubbed = CredentialScrubber.scrub(try #require(String(bytes: message, encoding: .utf8)))

        #expect(scrubbed == #"{"authId":"email:a***@example.com"}"#)
    }

    @Test(arguments: [
        "Loaded crossmint-sdk@1.2.3 in the signer frame",
        #"Web >> Native: {"event":"response:sign","data":{"signature":{"bytes":"0x1234abcd"}}}"#,
        "📍 URL: https://staging.crossmint.com/api/2025-06-09/wallets/0x8f3a1c2b4d5e6f708192a3b4c5d6e7f8"
    ])
    func leavesLinesWithoutPersonalDataIntact(logLine: String) {
        #expect(CredentialScrubber.scrub(logLine) == logLine)
    }
}
