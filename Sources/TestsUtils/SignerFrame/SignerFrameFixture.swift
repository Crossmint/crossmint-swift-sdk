import CrossmintCommonTypes
import Foundation
import Web

/// A `CrossmintTEE` wired to a scripted frame, a stub session and a signing key: no WebView, no network.
@MainActor
package struct SignerFrameFixture {
    package let authManager = MockAuthManager()
    package let frame = MockWebViewCommunicationProxy()
    package let key: SignerFrameKey
    package let tee: CrossmintTEE

    package init(isProductionEnvironment: Bool = false, apiKey: String = "ck_staging_test123") throws {
        NetworkKillSwitch.install()
        key = try SignerFrameKey()
        tee = CrossmintTEE(
            auth: authManager,
            webProxy: frame,
            apiKey: apiKey,
            isProductionEnvironment: isProductionEnvironment,
            signerStorage: MockSignerStorage()
        )
    }

    package func authenticate(jwt: String = SignerFrameMessages.createTestJWT()) async {
        await authManager.setJWT(jwt)
    }

    package func scriptHandshake(verificationId: String = "test123") {
        frame.configureResponse(
            for: HandshakeResponse.self,
            response: SignerFrameMessages.createHandshakeResponse(verificationId: verificationId)
        )
    }

    package func scriptReadyDevice() {
        frame.configureResponse(
            for: GetStatusResponse.self,
            response: SignerFrameMessages.createGetStatusResponse(signerStatus: .ready)
        )
    }

    package func scriptNewDevice() {
        frame.configureResponse(
            for: GetStatusResponse.self,
            response: SignerFrameMessages.createGetStatusResponse(signerStatus: .newDevice)
        )
        frame.configureResponse(
            for: StartOnboardingResponse.self,
            response: SignerFrameMessages.createStartOnboardingResponse()
        )
        frame.configureResponse(
            for: CompleteOnboardingResponse.self,
            response: SignerFrameMessages.createCompleteOnboardingResponse()
        )
    }

    package func scriptReadyNeverSent() {
        frame.configureResponse(
            for: GetStatusResponse.self,
            response: SignerFrameMessages.createGetStatusResponse(signerStatus: nil)
        )
    }

    package func scriptStorageUnavailable() {
        frame.configureResponse(
            for: GetStatusResponse.self,
            response: SignerFrameMessages.createGetStatusResponse(
                status: .error, signerStatus: nil, errorMessage: "IndexedDB is not available"
            )
        )
    }

    package func scriptSigning() {
        let key = key
        frame.signResponder = { request in
            SignerFrameMessages.createNonCustodialSignResponse(
                signature: (try? key.sign(hexBytes: request.data.data.bytes)) ?? ""
            )
        }
    }

    package func terminateFrame() {
        frame.onWebContentProcessTerminated()
    }

    package func waitForOTPRequired() async {
        for await required in tee.$isOTPRequired.values where required {
            return
        }
    }

    package func lastOtpSubmitted() -> String? {
        frame.lastSentMessage(ofType: CompleteOnboardingRequest.self)?.data.data.onboardingAuthentication.encryptedOtp
    }

    package func handshakeCount() -> Int {
        frame.sentMessages(ofType: HandshakeRequest.self).count
    }
}
