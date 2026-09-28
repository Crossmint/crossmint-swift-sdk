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

        let transaction = CrossmintTEETestHelpers.createTestTransaction()
        let signTask = Task {
            try await fixture.signTransaction(transaction: transaction)
        }

        await fixture.waitForOTPRequired()
        fixture.tee.provideOTP("123456")

        let signature = try await signTask.value
        #expect(signature == "0xsignature456")
        #expect(fixture.tee.isOTPRequired == false)

        try fixture.verifyOnboardingRequests(authId: expectedAuthId, channel: expectedChannel, otp: "123456")
        try fixture.verifySignRequest(expectedTransaction: transaction)
    }

    @Test func failsWithUserCancelledWhenOTPIsCancelled() async throws {
        let fixture = TEETestFixture()
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        fixture.configureNewDevice()
        fixture.configureOnboardingFlow()

        let signTask = Task {
            try await fixture.signTransaction(transaction: CrossmintTEETestHelpers.createTestTransaction())
        }

        await fixture.waitForOTPRequired()
        fixture.tee.cancelOTP()

        await #expect(throws: CrossmintTEE.Error.userCancelled) {
            _ = try await signTask.value
        }
        #expect(fixture.tee.isOTPRequired == false)
    }

    @Test func reonboardsWithFreshOTPWhenFrameReloadsMidOnboarding() async throws {
        let fixture = TEETestFixture()
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        fixture.configureNewDevice()
        let startOnboardingResponse = CrossmintTEETestHelpers.createStartOnboardingResponse()
        fixture.webProxy.configureResponse(for: StartOnboardingResponse.self, response: startOnboardingResponse)
        fixture.configureSignResponse(signature: "0xsignature_reonboard")

        let signTask = Task {
            try await fixture.signTransaction(transaction: CrossmintTEETestHelpers.createTestTransaction())
        }

        await fixture.waitForOTPRequired()
        fixture.tee.provideOTP("stale-otp")

        await fixture.waitForOTPRequired()
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

    @Test func onboardsQueuedRequestWithItsOwnIdentity() async throws {
        let fixture = TEETestFixture(identity: .phone("+15551234567", channel: .whatsapp))
        await fixture.setupAuthentication()

        let handshakeResponse = CrossmintTEETestHelpers.createHandshakeResponse(verificationId: "test123")
        fixture.webProxy.configureResponse(for: HandshakeResponse.self, response: handshakeResponse)
        fixture.configureNewDevice()
        fixture.configureOnboardingFlow()
        fixture.configureSignResponse(signature: "0xsignature456")

        let signTask = Task {
            try await fixture.signTransaction(transaction: CrossmintTEETestHelpers.createTestTransaction())
        }

        await fixture.waitForOTPRequired()
        fixture.tee.provideOTP("123456")
        _ = try await signTask.value

        try fixture.verifyOnboardingRequests(authId: "phone:+15551234567", channel: .whatsapp, otp: "123456")
    }
}
