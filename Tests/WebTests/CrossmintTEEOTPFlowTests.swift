//
//  CrossmintTEEOTPFlowTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 20/05/26.
//

import CrossmintAuth
import Foundation
import Testing
@testable import Web

@Suite("CrossmintTEE OTP Flow", .tags(.unit))
@MainActor struct CrossmintTEEOTPFlowTests {

    @Test("Sign succeeds after OTP verification")
    func succeedsAfterOTPVerification() async throws {
        let fixture = CrossmintTEEOTPFlowFixture()
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        fixture.configureNewDevice()
        fixture.configureOnboardingFlow()
        fixture.configureSignResponse(signature: "0xsignature_otp")

        let (signTask, capturedFlow) = await fixture.startSigningAndCaptureFlow()
        let flow = try #require(capturedFlow)
        try await flow.verifyOTP("123456")

        let signature = try await signTask.value
        #expect(signature == "0xsignature_otp")
    }

    @Test("Sign throws userCancelled when flow is cancelled")
    func throwsUserCancelledWhenFlowIsCancelled() async throws {
        let fixture = CrossmintTEEOTPFlowFixture()
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        fixture.configureNewDevice()
        fixture.configureOnboardingFlow()

        let (signTask, capturedFlow) = await fixture.startSigningAndCaptureFlow()
        let flow = try #require(capturedFlow)
        flow.cancel()

        await #expect(throws: CrossmintTEE.Error.userCancelled) {
            _ = try await signTask.value
        }
    }

    @Test("sendOTP triggers startOnboarding again")
    func triggersNewOnboardingRequestOnSendOTP() async throws {
        let fixture = CrossmintTEEOTPFlowFixture()
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        fixture.configureNewDevice()
        fixture.configureOnboardingFlow()
        fixture.configureSignResponse(signature: "0xsignature_resend")

        let (signTask, capturedFlow) = await fixture.startSigningAndCaptureFlow()
        let flow = try #require(capturedFlow)

        try await flow.sendOTP()

        let startOnboardingRequests = fixture.webProxy.sentMessages(ofType: StartOnboardingRequest.self)
        // First startOnboarding was called during newDevice handling, second via sendOTP
        #expect(startOnboardingRequests.count >= 2)

        try await flow.verifyOTP("654321")
        _ = try await signTask.value
    }

    @Test("Sign throws authMissing when no callback provided for new device")
    func throwsAuthMissingWithoutCallback() async throws {
        let fixture = CrossmintTEEOTPFlowFixture()
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        fixture.configureNewDevice()
        fixture.configureOnboardingFlow()

        await #expect(throws: CrossmintTEE.Error.authMissing) {
            _ = try await fixture.tee.signTransaction(
                transaction: CrossmintTEETestHelpers.createTestTransaction(),
                keyType: "keyType",
                encoding: "encoding",
                onAuthRequired: nil
            )
        }
    }

    @Test("onAuthRequired receives correct email address")
    func onAuthRequiredReceivesCorrectEmail() async throws {
        let TEST_EMAIL = "test@example.com"
        let fixture = CrossmintTEEOTPFlowFixture()
        await fixture.setupAuthentication(email: TEST_EMAIL)
        try await fixture.setupHandshake()

        fixture.configureNewDevice()
        fixture.configureOnboardingFlow()
        fixture.configureSignResponse(signature: "0xsignature_email")

        let emailCapture = OTPEmailCapture()

        let signTask = Task {
            try await fixture.tee.signTransaction(
                transaction: CrossmintTEETestHelpers.createTestTransaction(),
                keyType: "keyType",
                encoding: "encoding",
                onAuthRequired: { flow in
                    emailCapture.store(flow.email)
                    try? await flow.verifyOTP("000000")
                }
            )
        }

        let signature = try await signTask.value
        #expect(signature == "0xsignature_email")
        #expect(emailCapture.value == TEST_EMAIL)
    }
}
