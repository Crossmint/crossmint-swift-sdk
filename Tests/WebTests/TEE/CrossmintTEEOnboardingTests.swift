//
//  CrossmintTEEOnboardingTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 25/09/26.
//

import CrossmintAuth
import CrossmintCommonTypes
import Foundation
import Testing
@testable import Web

@Suite("CrossmintTEE Onboarding", .tags(.unit))
@MainActor
struct CrossmintTEEOnboardingTests {
    @Test(arguments: [
        (SignerIdentity.email("test@example.com"), "email:test@example.com", nil),
        (SignerIdentity.phone("+15551234567", channel: .whatsapp), "phone:+15551234567", OTPDeliveryChannel.whatsapp)
    ])
    func onboardsNewDeviceThenSigns(
        identity: SignerIdentity,
        expectedAuthId: String,
        expectedChannel: OTPDeliveryChannel?
    ) async throws {
        let fixture = TEETestFixture(identity: identity)
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        fixture.configureNewDevice()
        fixture.configureOnboardingFlow()
        fixture.configureSignResponse(signature: "0xsignature456")

        let signTask = Task {
            try await fixture.signTransaction(
                transaction: CrossmintTEETestHelpers.createTestTransaction(),
                keyType: "keyType",
                encoding: "encoding"
            )
        }

        try await fixture.waitForOTPRequired()

        fixture.tee.provideOTP("123456")

        let signature = try await signTask.value
        #expect(signature == "0xsignature456")
        #expect(fixture.tee.isOTPRequired == false)

        fixture.verifyOnboardingRequests(authId: expectedAuthId, channel: expectedChannel, otp: "123456")
        try fixture.verifySignRequest(expectedTransaction: CrossmintTEETestHelpers.createTestTransaction())
    }

    @Test("OTP cancellation handled correctly")
    func testOTPCancellation() async throws {
        let fixture = TEETestFixture()
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        fixture.configureNewDevice()
        fixture.configureOnboardingFlow()

        let signTask = Task {
            try await fixture.signTransaction(
                transaction: CrossmintTEETestHelpers.createTestTransaction(),
                keyType: "keyType",
                encoding: "encoding"
            )
        }

        try await fixture.waitForOTPRequired()

        fixture.tee.cancelOTP()

        await #expect(throws: CrossmintTEE.Error.userCancelled) {
            _ = try await signTask.value
        }

        #expect(fixture.tee.isOTPRequired == false)
    }

    @Test("Re-onboards with a fresh OTP when the frame reloads mid-onboarding")
    func testReonboardsWhenFrameReloadsMidOnboarding() async throws {
        let fixture = TEETestFixture()
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        fixture.configureNewDevice()
        let startOnboardingResponse = CrossmintTEETestHelpers.createStartOnboardingResponse()
        fixture.webProxy.configureResponse(for: StartOnboardingResponse.self, response: startOnboardingResponse)
        fixture.configureSignResponse(signature: "0xsignature_reonboard")

        let signTask = Task {
            try await fixture.signTransaction(
                transaction: CrossmintTEETestHelpers.createTestTransaction(),
                keyType: "keyType",
                encoding: "encoding"
            )
        }

        try await fixture.waitForOTPRequired()
        #expect(fixture.tee.isOTPRequired == true)
        fixture.tee.provideOTP("stale-otp")

        try await fixture.waitForOTPRequired()
        #expect(fixture.tee.isOTPRequired == true)

        let completeOnboardingResponse = CrossmintTEETestHelpers.createCompleteOnboardingResponse()
        fixture.webProxy.configureResponse(
            for: CompleteOnboardingResponse.self,
            response: completeOnboardingResponse
        )
        fixture.tee.provideOTP("fresh-otp")

        let signature = try await signTask.value
        #expect(signature == "0xsignature_reonboard")
        #expect(fixture.tee.isOTPRequired == false)
        #expect(fixture.webProxy.completeOnboardingRequestCount == 2)
    }

    @Test("A request that waits in the queue onboards with its own identity")
    func keepsTheIdentityOfAQueuedRequest() async throws {
        let fixture = TEETestFixture(identity: .phone("+15551234567", channel: .whatsapp))
        await fixture.setupAuthentication()

        // No setupHandshake, so the request is queued until the handshake resolves.
        let handshakeResponse = CrossmintTEETestHelpers.createHandshakeResponse(verificationId: "test123")
        fixture.webProxy.configureResponse(for: HandshakeResponse.self, response: handshakeResponse)
        fixture.configureNewDevice()
        fixture.configureOnboardingFlow()
        fixture.configureSignResponse(signature: "0xsignature456")

        let signTask = Task {
            try await fixture.signTransaction(
                transaction: CrossmintTEETestHelpers.createTestTransaction()
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
}
