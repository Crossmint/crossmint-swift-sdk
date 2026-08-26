import CrossmintAuth
import CrossmintCommonTypes
import Foundation
import Testing
@testable import Web

@Suite("Phone Onboarding", .tags(.unit))
@MainActor
struct CrossmintTEEPhoneOnboardingTests {
    @Test("Sends the phone auth id and the requested delivery channel")
    func sendsThePhoneAuthIdAndChannel() async throws {
        let fixture = TEETestFixture()
        await fixture.setupAuthentication(identity: .phone("+15551234567", channel: .whatsapp))
        try await fixture.setupHandshake()

        fixture.configureNewDevice()
        fixture.configureOnboardingFlow()
        fixture.configureSignResponse(signature: "0xsignature456")

        let signTask = Task {
            try await fixture.tee.signTransaction(
                transaction: CrossmintTEETestHelpers.createTestTransaction(),
                keyType: "keyType",
                encoding: "encoding"
            )
        }

        try await fixture.waitForOTPRequired()
        fixture.tee.provideOTP("123456")
        _ = try await signTask.value

        fixture.verifyOnboardingRequests(
            authId: "phone:+15551234567",
            channel: .whatsapp,
            otp: "123456"
        )
    }

    @Test("Onboards the identity the caller passed, not the one left on the TEE")
    func onboardsTheIdentityPassedWithTheRequest() async throws {
        let fixture = TEETestFixture()
        await fixture.setupAuthentication(identity: .email("admin@example.com"))
        try await fixture.setupHandshake()

        fixture.configureNewDevice()
        fixture.configureOnboardingFlow()
        fixture.configureSignResponse(signature: "0xsignature456")

        let signTask = Task {
            try await fixture.tee.signTransaction(
                transaction: CrossmintTEETestHelpers.createTestTransaction(),
                keyType: "keyType",
                encoding: "encoding",
                identity: .phone("+15551234567", channel: .sms)
            )
        }

        try await fixture.waitForOTPRequired()
        fixture.tee.provideOTP("123456")
        _ = try await signTask.value

        fixture.verifyOnboardingRequests(
            authId: "phone:+15551234567",
            channel: .sms,
            otp: "123456"
        )
    }

    @Test("Fails with authMissing when no signer identity is set")
    func failsWhenNoIdentityIsSet() async throws {
        let fixture = TEETestFixture()
        await fixture.authManager.setJWT(CrossmintTEETestHelpers.createTestJWT())
        fixture.tee.identity = nil
        try await fixture.setupHandshake()

        fixture.configureNewDevice()
        fixture.configureOnboardingFlow()

        await #expect(throws: CrossmintTEE.Error.authMissing) {
            try await fixture.tee.signTransaction(
                transaction: CrossmintTEETestHelpers.createTestTransaction(),
                keyType: "keyType",
                encoding: "encoding"
            )
        }
    }
}
