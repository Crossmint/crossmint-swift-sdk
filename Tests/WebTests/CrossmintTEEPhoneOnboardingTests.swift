//
//  CrossmintTEEPhoneOnboardingTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 26/08/26.
//

import CrossmintAuth
import CrossmintCommonTypes
import Foundation
import Testing
@testable import Web

@Suite("Phone Onboarding", .tags(.unit))
@MainActor
struct CrossmintTEEPhoneOnboardingTests {
    private static let phone = SignerIdentity.phone("+15551234567", channel: .whatsapp)

    @Test("Sends the phone auth id and the requested delivery channel")
    func sendsThePhoneAuthIdAndChannel() async throws {
        let fixture = TEETestFixture(identity: Self.phone)
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

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

    @Test("A request that waits in the queue onboards with its own identity")
    func keepsTheIdentityOfAQueuedRequest() async throws {
        let fixture = TEETestFixture(identity: Self.phone)
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
