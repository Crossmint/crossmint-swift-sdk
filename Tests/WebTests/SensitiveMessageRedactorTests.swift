import Foundation
import Testing
@testable import Web

@Suite("Sensitive Message Redactor", .tags(.unit))
struct SensitiveMessageRedactorTests {
    @Test("redacts apiKey and jwt from a sign request while keeping the event name")
    func redactsAuthDataFromSignRequest() throws {
        let request = NonCustodialSignRequest(
            jwt: "eyJhbGciOiJIUzI1NiJ9.super-secret-jwt",
            apiKey: "ck_staging_super-secret-key",
            messageBytes: "0xdeadbeef",
            keyType: "secp256k1",
            encoding: "hex"
        )
        let data = try JSONEncoder().encode(request)

        let logged = SensitiveMessageRedactor.redactedLoggableString(from: data)

        #expect(logged.contains("request:sign"))
        #expect(logged.contains("0xdeadbeef"))
        #expect(!logged.contains("super-secret-jwt"))
        #expect(!logged.contains("ck_staging_super-secret-key"))
    }

    @Test("redacts encryptedOtp from a complete-onboarding request while keeping the event name")
    func redactsEncryptedOtpFromOnboardingRequest() throws {
        let request = CompleteOnboardingRequest(
            jwt: "eyJhbGciOiJIUzI1NiJ9.super-secret-jwt",
            apiKey: "ck_staging_super-secret-key",
            otp: "super-secret-encrypted-otp"
        )
        let data = try JSONEncoder().encode(request)

        let logged = SensitiveMessageRedactor.redactedLoggableString(from: data)

        #expect(logged.contains("request:complete-onboarding"))
        #expect(!logged.contains("super-secret-jwt"))
        #expect(!logged.contains("ck_staging_super-secret-key"))
        #expect(!logged.contains("super-secret-encrypted-otp"))
    }

    @Test("leaves non-sensitive fields and structure untouched")
    func preservesNonSensitiveFields() throws {
        let request = HandshakeRequest(requestVerificationId: "ABC123")
        let data = try JSONEncoder().encode(request)

        let logged = SensitiveMessageRedactor.redactedLoggableString(from: data)

        #expect(logged.contains("handshakeRequest"))
        #expect(logged.contains("ABC123"))
    }

    @Test("falls back to a placeholder for unparseable data")
    func fallsBackForUnparseableData() {
        let data = Data("not json".utf8)

        let logged = SensitiveMessageRedactor.redactedLoggableString(from: data)

        #expect(logged == "<unparseable message>")
    }
}
