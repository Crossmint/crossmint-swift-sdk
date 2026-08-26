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

    func waitForOTPRequired() async throws {
        var attempts = 0
        while !tee.isOTPRequired {
            if attempts >= 100 {
                throw CrossmintTEE.Error.generic("Timed out waiting for the OTP prompt")
            }
            await Task.yield()
            attempts += 1
        }
    }

    func verifyHandshakeCompleted(verificationId: String) {
        let sentHandshakeRequest = webProxy.lastSentMessage(ofType: HandshakeRequest.self)
        #expect(sentHandshakeRequest != nil)

        let sentHandshakeComplete = webProxy.lastSentMessage(ofType: HandshakeComplete.self)
        #expect(sentHandshakeComplete != nil)
        #expect(sentHandshakeComplete?.data.requestVerificationId == verificationId)
    }

    func verifySignRequest(expectedTransaction: String) {
        let statusRequest = webProxy.lastSentMessage(ofType: GetStatusRequest.self)
        #expect(statusRequest != nil)
        #expect(statusRequest?.data.authData.jwt == CrossmintTEETestHelpers.createTestJWT())

        let signRequest = webProxy.lastSentMessage(ofType: NonCustodialSignRequest.self)
        #expect(signRequest != nil)
        #expect(signRequest?.data.data.bytes == expectedTransaction)
    }

    func verifyOnboardingRequests(authId: String, channel: OTPDeliveryChannel?, otp: String) {
        let startOnboardingRequest = webProxy.lastSentMessage(ofType: StartOnboardingRequest.self)
        #expect(startOnboardingRequest != nil)
        #expect(startOnboardingRequest?.data.data.authId == authId)
        #expect(startOnboardingRequest?.data.data.channel == channel)

        let completeOnboardingRequest = webProxy.lastSentMessage(ofType: CompleteOnboardingRequest.self)
        #expect(completeOnboardingRequest != nil)
        #expect(completeOnboardingRequest?.data.data.onboardingAuthentication.encryptedOtp == otp)
    }
}

@Suite("CrossmintTEE Tests", .tags(.unit))
struct CrossmintTEETests {

    @Suite("Handshake")
    @MainActor
    struct HandshakeTests {
        @Test("Successfully completes handshake on first attempt")
        func testSuccessfulHandshakeFirstAttempt() async throws {
            let fixture = TEETestFixture()
            try await fixture.setupHandshake(verificationId: "test123")

            fixture.verifyHandshakeCompleted(verificationId: "test123")

            #expect(fixture.webProxy.loadedURLs.count == 1)
            #expect(fixture.webProxy.loadedURLs.first?.absoluteString.contains("signers.crossmint.com") == true)
        }

        @Test("Retries handshake on timeout up to 3 times")
        func testHandshakeRetryOnTimeout() async throws {
            let fixture = TEETestFixture()

            await #expect(throws: CrossmintTEE.Error.handshakeFailed) {
                try await fixture.tee.load()
            }

            let handshakeRequests = fixture.webProxy.sentMessages(ofType: HandshakeRequest.self)
            #expect(handshakeRequests.count == 3)
        }

        @Test("Resets state correctly")
        func testResetState() async throws {
            let fixture = TEETestFixture()
            try await fixture.setupHandshake()

            fixture.tee.resetState()
            fixture.webProxy.clearResponse(for: HandshakeResponse.self)

            #expect(fixture.webProxy.resetCount == 1)

            await #expect(throws: CrossmintTEE.Error.handshakeFailed) {
                _ = try await fixture.signTransaction(
                    transaction: "test",
                    keyType: "keyType",
                    encoding: "encoding"
                )
            }
        }

        @Test("Load fails when URL is not available")
        func testLoadFailsWhenURLNotAvailable() async throws {
            let fixture = TEETestFixture()

            fixture.webProxy.shouldThrowOnLoad = true
            fixture.webProxy.loadError = WebViewError.webViewNotAvailable

            await #expect(throws: CrossmintTEE.Error.urlNotAvailable) {
                try await fixture.tee.load()
            }
        }
    }

    @Suite("Signing")
    @MainActor
    struct SigningTests {
        @Test("Signs transaction when device is ready")
        func testSignTransactionWhenDeviceReady() async throws {
            let fixture = TEETestFixture()
            await fixture.setupAuthentication()
            try await fixture.setupHandshake()

            fixture.configureReadyDevice()
            fixture.configureSignResponse(signature: "0xsignature123")

            let transaction = CrossmintTEETestHelpers.createTestTransaction()
            let signature = try await fixture.signTransaction(
                transaction: transaction,
                keyType: "keyType",
                encoding: "encoding"
            )

            #expect(signature == "0xsignature123")
            fixture.verifySignRequest(expectedTransaction: transaction)
        }

        @Test("Signing fails without handshake")
        func testSigningFailsWithoutHandshake() async throws {
            let fixture = TEETestFixture()

            await #expect(throws: CrossmintTEE.Error.handshakeFailed) {
                _ = try await fixture.signTransaction(
                    transaction: "test",
                    keyType: "keyType",
                    encoding: "encoding"
                )
            }
        }

        @Test("Signing fails without JWT")
        func testSigningFailsWithoutJWT() async throws {
            let fixture = TEETestFixture()
            try await fixture.setupHandshake()

            await #expect(throws: CrossmintTEE.Error.jwtRequired) {
                _ = try await fixture.signTransaction(
                    transaction: "test",
                    keyType: "keyType",
                    encoding: "encoding"
                )
            }
        }

        @Test("Handles server error response")
        func testHandlesServerErrorResponse() async throws {
            let fixture = TEETestFixture()
            await fixture.setupAuthentication()
            try await fixture.setupHandshake()

            fixture.configureErrorResponse(errorMessage: "Server error occurred")

            await #expect(throws: CrossmintTEE.Error.generic("Server error occurred")) {
                _ = try await fixture.signTransaction(
                    transaction: "test",
                    keyType: "keyType",
                    encoding: "encoding"
                )
            }
        }

        @Test("Handles invalid signature response")
        func testHandlesInvalidSignatureResponse() async throws {
            let fixture = TEETestFixture()
            await fixture.setupAuthentication()
            try await fixture.setupHandshake()

            fixture.configureReadyDevice()

            let signResponse = CrossmintTEETestHelpers.createNonCustodialSignResponse(
                signature: "",
                status: .success
            )
            fixture.webProxy.configureResponse(for: NonCustodialSignResponse.self, response: signResponse)

            await #expect(throws: CrossmintTEE.Error.invalidSignature) {
                _ = try await fixture.signTransaction(
                    transaction: "test",
                    keyType: "keyType",
                    encoding: "encoding"
                )
            }
        }

        @Test("Rejects non-hex signature when hex encoding was requested")
        func testRejectsNonHexSignatureForHexEncoding() async throws {
            let fixture = TEETestFixture()
            await fixture.setupAuthentication()
            try await fixture.setupHandshake()

            fixture.configureReadyDevice()
            fixture.configureSignResponse(signature: "not-a-hex-ecdsa-signature")

            await #expect(throws: CrossmintTEE.Error.invalidSignature) {
                _ = try await fixture.signTransaction(
                    transaction: CrossmintTEETestHelpers.createTestTransaction(),
                    keyType: "secp256k1",
                    encoding: "hex"
                )
            }
        }

        @Test("Returns hex signature verbatim even when its bytes decode as UTF-8")
        func testHexSignatureIsNotDecodedAsUTF8() async throws {
            let fixture = TEETestFixture()
            await fixture.setupAuthentication()
            try await fixture.setupHandshake()

            fixture.configureReadyDevice()
            // 0x48656c6c6f decodes to the UTF-8 string "Hello"; the signature
            // must be passed through verbatim, not decoded (regression for WAL-11310).
            fixture.configureSignResponse(signature: "0x48656c6c6f")

            let signature = try await fixture.signTransaction(
                transaction: CrossmintTEETestHelpers.createTestTransaction(),
                keyType: "secp256k1",
                encoding: "hex"
            )

            #expect(signature == "0x48656c6c6f")
        }

        @Test("Throws when the frame reports an error status for the sign request")
        func testThrowsOnSignErrorStatus() async throws {
            let fixture = TEETestFixture()
            await fixture.setupAuthentication()
            try await fixture.setupHandshake()

            fixture.configureReadyDevice()

            let signResponse = CrossmintTEETestHelpers.createNonCustodialSignResponse(
                signature: "",
                status: .error,
                errorMessage: "Signing failed in frame"
            )
            fixture.webProxy.configureResponse(for: NonCustodialSignResponse.self, response: signResponse)

            await #expect(throws: CrossmintTEE.Error.generic("Signing failed in frame")) {
                _ = try await fixture.signTransaction(
                    transaction: "test",
                    keyType: "keyType",
                    encoding: "encoding"
                )
            }
        }
    }

    @Suite("Onboarding")
    @MainActor
    struct OnboardingTests {
        @Test("Completes full onboarding flow for new device")
        func testFullOnboardingFlowForNewDevice() async throws {
            let fixture = TEETestFixture()
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

            fixture.verifyOnboardingRequests(authId: "email:test@example.com", channel: nil, otp: "123456")
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

        @Test("isOTPRequired property updates correctly")
        func testIsOTPRequiredPropertyUpdates() async throws {
            let fixture = TEETestFixture()
            await fixture.setupAuthentication()
            try await fixture.setupHandshake()

            #expect(fixture.tee.isOTPRequired == false)

            fixture.configureNewDevice()
            fixture.configureOnboardingFlow()
            fixture.configureSignResponse(signature: "0xsignature789")

            let signTask = Task {
                try await fixture.signTransaction(
                    transaction: CrossmintTEETestHelpers.createTestTransaction(),
                    keyType: "keyType",
                    encoding: "encoding"
                )
            }

            try await fixture.waitForOTPRequired()

            fixture.tee.provideOTP("123456")

            _ = try await signTask.value

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
    }
}
