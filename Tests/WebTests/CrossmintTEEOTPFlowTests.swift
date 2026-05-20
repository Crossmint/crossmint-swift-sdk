import CrossmintAuth
import Foundation
import Testing
@testable import Web

@Suite("CrossmintTEE OTP Flow", .tags(.unit))
@MainActor struct CrossmintTEEOTPFlowTests {

    @MainActor
    struct TestFixture {
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
    }

    @Test("Sign succeeds after OTP verification")
    func signSucceedsAfterOTPVerification() async throws {
        let fixture = TestFixture()
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        fixture.configureNewDevice()
        fixture.configureOnboardingFlow()
        fixture.configureSignResponse(signature: "0xsignature_otp")

        let flowBox = OTPFlowBox()

        let signTask = Task {
            try await fixture.tee.signTransaction(
                transaction: CrossmintTEETestHelpers.createTestTransaction(),
                keyType: "keyType",
                encoding: "encoding",
                onAuthRequired: { flow in
                    flowBox.store(flow)
                }
            )
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        let flow = try #require(flowBox.value)
        try await flow.verifyOTP("123456")

        let signature = try await signTask.value
        #expect(signature == "0xsignature_otp")
    }

    @Test("Sign throws userCancelled when flow is cancelled")
    func signThrowsUserCancelledWhenCancelled() async throws {
        let fixture = TestFixture()
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        fixture.configureNewDevice()
        fixture.configureOnboardingFlow()

        let flowBox = OTPFlowBox()

        let signTask = Task {
            try await fixture.tee.signTransaction(
                transaction: CrossmintTEETestHelpers.createTestTransaction(),
                keyType: "keyType",
                encoding: "encoding",
                onAuthRequired: { flow in
                    flowBox.store(flow)
                }
            )
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        let flow = try #require(flowBox.value)
        flow.cancel()

        await #expect(throws: CrossmintTEE.Error.userCancelled) {
            _ = try await signTask.value
        }
    }

    @Test("sendOTP triggers startOnboarding again")
    func sendOTPTriggersStartOnboardingAgain() async throws {
        let fixture = TestFixture()
        await fixture.setupAuthentication()
        try await fixture.setupHandshake()

        fixture.configureNewDevice()
        fixture.configureOnboardingFlow()
        fixture.configureSignResponse(signature: "0xsignature_resend")

        let flowBox = OTPFlowBox()

        let signTask = Task {
            try await fixture.tee.signTransaction(
                transaction: CrossmintTEETestHelpers.createTestTransaction(),
                keyType: "keyType",
                encoding: "encoding",
                onAuthRequired: { flow in
                    flowBox.store(flow)
                }
            )
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        let flow = try #require(flowBox.value)

        try? await flow.sendOTP()

        let startOnboardingRequests = fixture.webProxy.sentMessages(ofType: StartOnboardingRequest.self)
        // First startOnboarding was called during newDevice handling, second via sendOTP
        #expect(startOnboardingRequests.count >= 2)

        try await flow.verifyOTP("654321")
        _ = try await signTask.value
    }

    @Test("Sign throws authMissing when no callback provided for new device")
    func signThrowsAuthMissingWhenNoCallback() async throws {
        let fixture = TestFixture()
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

    @Test("onAuthRequired receives email signer with correct address")
    func onAuthRequiredReceivesEmailSigner() async throws {
        let testEmail = "test@example.com"
        let fixture = TestFixture()
        await fixture.setupAuthentication(email: testEmail)
        try await fixture.setupHandshake()

        fixture.configureNewDevice()
        fixture.configureOnboardingFlow()
        fixture.configureSignResponse(signature: "0xsignature_email")

        let signerBox = OTPSignerBox()

        let signTask = Task {
            try await fixture.tee.signTransaction(
                transaction: CrossmintTEETestHelpers.createTestTransaction(),
                keyType: "keyType",
                encoding: "encoding",
                onAuthRequired: { flow in
                    signerBox.store(flow.signer)
                    try? await flow.verifyOTP("000000")
                }
            )
        }

        let signature = try await signTask.value
        #expect(signature == "0xsignature_email")

        switch signerBox.value {
        case .email(let addr):
            #expect(addr == testEmail)
        default:
            Issue.record("Expected email signer but got \(String(describing: signerBox.value))")
        }
    }
}

// MARK: - Helpers

/// Thread-safe box for capturing an OTPFlow from a @Sendable closure.
final class OTPFlowBox: @unchecked Sendable {
    private var _value: OTPFlow?
    func store(_ flow: OTPFlow) { _value = flow }
    var value: OTPFlow? { _value }
}

/// Thread-safe box for capturing an OTPFlow.Signer from a @Sendable closure.
final class OTPSignerBox: @unchecked Sendable {
    private var _value: OTPFlow.Signer?
    func store(_ signer: OTPFlow.Signer) { _value = signer }
    var value: OTPFlow.Signer? { _value }
}
