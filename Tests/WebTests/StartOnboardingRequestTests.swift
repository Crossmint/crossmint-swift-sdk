//
//  StartOnboardingRequestTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 26/08/26.
//

import CrossmintCommonTypes
import Foundation
import Testing
@testable import Web

@Suite("Start Onboarding Request", .tags(.unit))
struct StartOnboardingRequestTests {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private func encodeData(_ request: StartOnboardingRequest) throws -> String {
        let raw = try encoder.encode(request.data.data)
        return String(bytes: raw, encoding: .utf8) ?? ""
    }

    private func makeRequest(authId: String, channel: OTPDeliveryChannel?) -> StartOnboardingRequest {
        StartOnboardingRequest(jwt: "test-jwt", apiKey: "test-api-key", authId: authId, channel: channel)
    }

    @Test func omitsChannelWhenUnset() throws {
        let json = try encodeData(makeRequest(authId: "email:user@example.com", channel: nil))
        #expect(json == #"{"authId":"email:user@example.com"}"#)
    }

    @Test func encodesWhatsappChannel() throws {
        let json = try encodeData(makeRequest(authId: "phone:+15551234567", channel: .whatsapp))
        #expect(json == #"{"authId":"phone:+15551234567","channel":"whatsapp"}"#)
    }

    @Test func encodesSmsChannel() throws {
        let json = try encodeData(makeRequest(authId: "phone:+15551234567", channel: .sms))
        #expect(json == #"{"authId":"phone:+15551234567","channel":"sms"}"#)
    }

    @Test func buildsAuthIdAndChannelFromAPhoneIdentity() throws {
        let identity = SignerIdentity.phone("+15551234567", channel: .whatsapp)
        #expect(identity.authId == "phone:+15551234567")
        #expect(identity.channel == .whatsapp)
    }

    @Test func reportsNoChannelForAnEmailIdentity() throws {
        let identity = SignerIdentity.email("user@example.com")
        #expect(identity.authId == "email:user@example.com")
        #expect(identity.channel == nil)
    }
}
