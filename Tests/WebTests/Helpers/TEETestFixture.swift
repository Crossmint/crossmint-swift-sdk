//
//  TEETestFixture.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 25/09/26.
//

import CrossmintAuth
import CrossmintCommonTypes
import Foundation
import Testing
@testable import Web

@MainActor
struct TEETestFixture {
    let authManager = MockAuthManager()
    let webProxy = MockWebViewCommunicationProxy()
    let apiKey = "test-api-key"
    let identity: SignerIdentity
    let tee: CrossmintTEE

    init(
        isProductionEnvironment: Bool = true,
        identity: SignerIdentity = .email("test@example.com")
    ) {
        self.identity = identity
        self.tee = CrossmintTEE(
            auth: authManager,
            webProxy: webProxy,
            apiKey: apiKey,
            isProductionEnvironment: isProductionEnvironment,
            signerStorage: MockSignerStorage()
        )
    }

    func setupAuthentication(jwt: String? = nil) async {
        await authManager.setJWT(jwt ?? CrossmintTEETestHelpers.createTestJWT())
    }

    /// Mirrors production, where the signer owns its identity and passes it with each request.
    func signTransaction(
        transaction: String,
        keyType: String = "keyType",
        encoding: String = "encoding"
    ) async throws(CrossmintTEE.Error) -> String {
        try await tee.signTransaction(
            transaction: transaction,
            keyType: keyType,
            encoding: encoding,
            identity: identity
        )
    }

    func setupHandshake(verificationId: String = "test123") async throws {
        let handshakeResponse = CrossmintTEETestHelpers.createHandshakeResponse(verificationId: verificationId)
        webProxy.configureResponse(for: HandshakeResponse.self, response: handshakeResponse)
        try await tee.load()
    }

    func configureReadyDevice() {
        let statusResponse = CrossmintTEETestHelpers.createGetStatusResponse(
            status: .success,
            signerStatus: .ready
        )
        webProxy.configureResponse(for: GetStatusResponse.self, response: statusResponse)
    }

    func configureNewDevice() {
        let statusResponse = CrossmintTEETestHelpers.createGetStatusResponse(
            status: .success,
            signerStatus: .newDevice
        )
        webProxy.configureResponse(for: GetStatusResponse.self, response: statusResponse)
    }

    func configureOnboardingFlow() {
        let startOnboardingResponse = CrossmintTEETestHelpers.createStartOnboardingResponse()
        webProxy.configureResponse(for: StartOnboardingResponse.self, response: startOnboardingResponse)

        let completeOnboardingResponse = CrossmintTEETestHelpers.createCompleteOnboardingResponse()
        webProxy.configureResponse(for: CompleteOnboardingResponse.self, response: completeOnboardingResponse)
    }

    func configureSignResponse(signature: String) {
        let signResponse = CrossmintTEETestHelpers.createNonCustodialSignResponse(
            signature: signature
        )
        webProxy.configureResponse(for: NonCustodialSignResponse.self, response: signResponse)
    }

    func configureErrorResponse(errorMessage: String) {
        let statusResponse = CrossmintTEETestHelpers.createGetStatusResponse(
            status: .error,
            signerStatus: nil,
            errorMessage: errorMessage
        )
        webProxy.configureResponse(for: GetStatusResponse.self, response: statusResponse)
    }

    func waitForOTPRequired() async {
        for await required in tee.$isOTPRequired.values where required {
            return
        }
    }

    func verifyHandshakeCompleted(verificationId: String) throws {
        try #require(webProxy.lastSentMessage(ofType: HandshakeRequest.self) != nil)

        let sentHandshakeComplete = try #require(webProxy.lastSentMessage(ofType: HandshakeComplete.self))
        #expect(sentHandshakeComplete.data.requestVerificationId == verificationId)
    }

    func verifySignRequest(expectedTransaction: String) throws {
        let statusRequest = try #require(webProxy.lastSentMessage(ofType: GetStatusRequest.self))
        #expect(statusRequest.data.authData.jwt == CrossmintTEETestHelpers.createTestJWT())
        #expect(try wireAuthId(statusRequest) == identity.authId)

        let signRequest = try #require(webProxy.lastSentMessage(ofType: NonCustodialSignRequest.self))
        #expect(signRequest.data.data.bytes == expectedTransaction)
        #expect(try wireAuthId(signRequest) == identity.authId)
    }

    /// The frame reads the recovery method from `data.data.authId` on the wire, so assert on the encoded JSON.
    private func wireAuthId(_ message: some Encodable) throws -> String? {
        let encoded = try JSONEncoder().encode(message)
        return try JSONDecoder().decode(WireMessage.self, from: encoded).data.data.authId
    }

    func verifyOnboardingRequests(authId: String, channel: OTPDeliveryChannel?, otp: String) throws {
        let startOnboardingRequest = try #require(webProxy.lastSentMessage(ofType: StartOnboardingRequest.self))
        #expect(startOnboardingRequest.data.data.authId == authId)
        #expect(startOnboardingRequest.data.data.channel == channel)

        let completeOnboardingRequest = try #require(webProxy.lastSentMessage(ofType: CompleteOnboardingRequest.self))
        #expect(completeOnboardingRequest.data.data.onboardingAuthentication.encryptedOtp == otp)
    }
}

private struct WireMessage: Decodable {
    struct Envelope: Decodable {
        struct Payload: Decodable {
            let authId: String?
        }

        let data: Payload
    }

    let data: Envelope
}
