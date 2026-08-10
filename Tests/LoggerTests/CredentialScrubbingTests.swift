//
//  CredentialScrubbingTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 04/08/26.
//

@testable import Logger
import Testing

private let JWT = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0ZXN0LWZpeHR1cmUifQ.notARealSignatureJustTestData01"
private let API_KEY = "ck_staging_notARealApiKeyJustTestData01"
private let OTP = "notARealEncryptedOtpJustTestData01"

@Suite("Credential scrubbing", .tags(.unit))
struct CredentialScrubbingTests {
    @Test func redactsAuthDataFromSignRequest() {
        let message = """
        Native >> Web: {"data":{"authData":{"jwt":"\(JWT)","apiKey":"\(API_KEY)"},\
        "data":{"bytes":"de42f2e6","encoding":"hex","keyType":"secp256k1"}},"event":"request:sign"}
        """

        let scrubbed = CredentialScrubber.scrub(message)

        #expect(!scrubbed.contains(JWT))
        #expect(!scrubbed.contains(API_KEY))
        #expect(scrubbed.contains("request:sign"))
        #expect(scrubbed.contains("secp256k1"))
    }

    @Test func redactsEncryptedOtpNestedDeeperThanOneLevel() {
        let message = """
        {"event":"request:complete-onboarding","data":\
        {"onboardingAuthentication":{"meta":{"attempt":1},"encryptedOtp":"\(OTP)"}}}
        """

        let scrubbed = CredentialScrubber.scrub(message)

        #expect(!scrubbed.contains(OTP))
        #expect(scrubbed.contains("request:complete-onboarding"))
    }

    @Test func redactsUnrecognisedFieldsInsideCredentialContainers() {
        let message = #"{"authData":{"sessionSecret":"notARealSecretJustTestData01"}}"#

        #expect(CredentialScrubber.scrub(message) == #"{"authData":"[REDACTED]"}"#)
    }

    @Test func redactsEveryApiKeyPrefix() {
        let keys = [
            "ck_development_notARealApiKeyJustTestData01",
            "ck_staging_notARealApiKeyJustTestData01",
            "ck_production_notARealApiKeyJustTestData01",
            "sk_production_notARealApiKeyJustTestData01"
        ]

        for key in keys {
            #expect(!CredentialScrubber.scrub("key=\(key)").contains(key))
        }
    }

    @Test func redactsCredentialsOutsideJsonContainers() {
        let scrubbed = CredentialScrubber.scrub("refreshed token=\(JWT) using \(API_KEY)")

        #expect(scrubbed == "refreshed token=[REDACTED_JWT] using [REDACTED_API_KEY]")
    }

    @Test func leavesResponsesWithoutCredentialsIntact() {
        let message = """
        Web >> Native: {"event":"response:get-status","data":{"status":"success","signerStatus":"new-device"}}
        """

        #expect(CredentialScrubber.scrub(message) == message)
    }

    @Test func scrubsStringAttributesReachingProviders() {
        let provider = MockLoggerProvider()
        let logger = Logger(testProviders: [provider])

        logger.error("sign failed", attributes: ["context": "key \(API_KEY)"])

        #expect(provider.lastAttributes?["context"] as? String == "key [REDACTED_API_KEY]")
    }

    @Test func compilesEveryPattern() {
        #expect(CredentialScrubber.patterns.count == 4)
    }

    @Test func leavesNonStringAttributesUntouched() {
        let provider = MockLoggerProvider()
        let logger = Logger(testProviders: [provider])

        logger.debug("sending", attributes: ["attempt": 2])

        #expect(provider.lastAttributes?["attempt"] as? Int == 2)
    }

    @Test func scrubsEveryLogLevel() {
        let provider = MockLoggerProvider()
        let logger = Logger(testProviders: [provider])

        logger.debug(JWT)
        #expect(provider.lastMessage == "[REDACTED_JWT]")

        logger.info(JWT)
        #expect(provider.lastMessage == "[REDACTED_JWT]")

        logger.warning(JWT)
        #expect(provider.lastMessage == "[REDACTED_JWT]")

        logger.error(JWT)
        #expect(provider.lastMessage == "[REDACTED_JWT]")
    }
}
