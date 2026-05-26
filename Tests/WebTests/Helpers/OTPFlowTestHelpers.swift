//
//  OTPFlowTestHelpers.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 20/05/26.
//

import CrossmintAuth
import Foundation
@testable import Web

@MainActor
struct CrossmintTEEOTPFlowFixture {
    let authManager = MockAuthManager()
    let webProxy = MockWebViewCommunicationProxy()
    let apiKey = "test-api-key"
    let tee: CrossmintTEE

    init() {
        self.tee = CrossmintTEE(
            auth: authManager,
            webProxy: webProxy,
            apiKey: apiKey,
            isProductionEnvironment: true
        )
    }

    func setupAuthentication(email: String = "test@example.com") async {
        await authManager.setJWT(CrossmintTEETestHelpers.createTestJWT())
        tee.email = email
    }

    func setupHandshake() async throws {
        let handshakeResponse = CrossmintTEETestHelpers.createHandshakeResponse(verificationId: "test123")
        webProxy.configureResponse(for: HandshakeResponse.self, response: handshakeResponse)
        try await tee.load()
    }

    func configureNewDevice() {
        let statusResponse = CrossmintTEETestHelpers.createGetStatusResponse(
            status: .success,
            signerStatus: .newDevice
        )
        webProxy.configureResponse(for: GetStatusResponse.self, response: statusResponse)
    }

    func configureOnboardingFlow() {
        webProxy.configureResponse(
            for: StartOnboardingResponse.self,
            response: CrossmintTEETestHelpers.createStartOnboardingResponse()
        )
        webProxy.configureResponse(
            for: CompleteOnboardingResponse.self,
            response: CrossmintTEETestHelpers.createCompleteOnboardingResponse()
        )
    }

    func configureSignResponse(signature: String) {
        webProxy.configureResponse(
            for: NonCustodialSignResponse.self,
            response: CrossmintTEETestHelpers.createNonCustodialSignResponse(signature: signature)
        )
    }

    func startSigningAndCaptureFlow() async -> (signTask: Task<String, any Error>, flow: OTPFlow?) {
        let (flowStream, flowContinuation) = AsyncStream<OTPFlow>.makeStream()
        let signTask = Task {
            try await tee.signTransaction(
                transaction: CrossmintTEETestHelpers.createTestTransaction(),
                keyType: "keyType",
                encoding: "encoding",
                onAuthRequired: { flow in
                    flowContinuation.yield(flow)
                    flowContinuation.finish()
                }
            )
        }
        var receivedFlow: OTPFlow?
        for await flow in flowStream { receivedFlow = flow }
        return (signTask, receivedFlow)
    }
}

final class OTPEmailCapture: @unchecked Sendable {
    private var _value: String?
    func store(_ email: String) { _value = email }
    var value: String? { _value }
}
