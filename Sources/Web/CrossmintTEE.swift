import Auth
import Combine
import Logger

extension Logger {
    static let tee = Logger(category: "TEE")
}

@MainActor private var teeInstances = 0

@MainActor
public final class CrossmintTEE: ObservableObject {
    public private(set) static var shared: CrossmintTEE?

    public enum Error: Swift.Error, Equatable {
        case handshakeFailed
        case timeout
        case handshakeRequired
        case jwtRequired
        case generic(String)
        case authMissing
        case urlNotAvailable
        case userCancelled
        case newerSignatureRequested
        case invalidSignature
        case queueTimeout
    }

    private enum HandshakeState {
        case idle
        case inProgress
        case completed
        case failed(CrossmintTEE.Error)
    }

    private struct PendingSignRequest {
        let id: UUID
        let transaction: String
        let keyType: String
        let encoding: String
        let callback: (Result<String, CrossmintTEE.Error>) -> Void
        let timeoutTask: Task<Void, Never>
    }

    public let webProxy: WebViewCommunicationProxy

    private let url: URL
    private var handshakeState: HandshakeState = .idle
    private var signRequestQueue: [PendingSignRequest] = []
    private let auth: AuthManager
    private let apiKey: String
    public var email: String?

    private var otpContinuation: CheckedContinuation<String, Swift.Error>?
    @Published public var isOTPRequired = false

    init(
        auth: AuthManager,
        webProxy: WebViewCommunicationProxy,
        apiKey: String,
        isProductionEnvironment: Bool
    ) {
        teeInstances += 1
        if teeInstances > 1 {
            Logger.tee.error("Multiple TEE instances created. Behaviour is undefined")
        }

        self.webProxy = webProxy
        // swiftlint:disable force_unwrapping
        self.url = isProductionEnvironment
            ? URL(string: "https://signers.crossmint.com")!
            : URL(string: "https://staging.signers.crossmint.com")!
        // swiftlint:enable force_unwrapping
        self.auth = auth
        self.apiKey = apiKey
    }

    deinit {
        Task { @MainActor in
            teeInstances -= 1
        }
    }

    public func signTransaction(
        transaction: String,
        keyType: String,
        encoding: String
    ) async throws(Error) -> String {
        Logger.tee.debug("signTransaction() called - keyType: \(keyType), encoding: \(encoding), handshake state: \(handshakeState)")

        if case .completed = handshakeState {
            Logger.tee.debug("Handshake already completed, executing sign transaction directly")
            return try await executeSignTransaction(
                transaction: transaction,
                keyType: keyType,
                encoding: encoding
            )
        }

        switch handshakeState {
        case .idle, .failed:
            Logger.tee.debug("Handshake not ready (state: \(handshakeState)), initiating load and queueing request")
            handshakeState = .idle
            Task {
                try? await load()
            }
        case .inProgress, .completed:
            Logger.tee.debug("Handshake in progress, queueing sign request")
            break
        }

        return try await queueSignRequest(transaction: transaction, keyType: keyType, encoding: encoding)
    }

    private func executeSignTransaction(
        transaction: String,
        keyType: String,
        encoding: String
    ) async throws(Error) -> String {
        Logger.tee.debug("executeSignTransaction() - Starting sign transaction flow")

        guard let jwt = await auth.jwt else {
            Logger.tee.warn("JWT is missing, cannot proceed with signing")
            throw .jwtRequired
        }
        Logger.tee.debug("JWT retrieved successfully")

        let response = try await self.tryGetStatus(jwt: jwt, maxAttempts: 3)
        switch response.status {
        case .success:
            guard let signerStatus = response.signerStatus else {
                Logger.tee.error("Frame returned successful status response without signer: \(response)")
                throw .generic("Signer status missing from response")
            }
            switch signerStatus {
            case .newDevice:
                Logger.tee.debug("Signer status is newDevice, starting onboarding flow")
                let onboardingResponse = try await startOnboarding(
                    jwt: jwt,
                    authId: try getAuthId()
                )

                guard onboardingResponse.status == .success else {
                    Logger.tee.error("Received onboarding response error: \(onboardingResponse.errorMessage ?? "")")
                    throw .generic("Invalid NCS status")
                }
                Logger.tee.debug("Onboarding started successfully, waiting for OTP")

                let otpCode: String = try await waitForOTP()
                Logger.tee.debug("OTP received, validating")
                _ = try await validate(otpCode: otpCode, jwt: jwt)
                Logger.tee.debug("OTP validated successfully, proceeding to sign")

                let signature = try await sign(
                    .init(
                        jwt: jwt,
                        apiKey: apiKey,
                        messageBytes: transaction,
                        keyType: keyType,
                        encoding: encoding)
                ).stringValue
                Logger.tee.debug("Transaction signed successfully after onboarding")
                return signature
            case .ready:
                Logger.tee.debug("Signer is ready, proceeding directly to sign")
                let signature = try await sign(
                    .init(
                        jwt: jwt,
                        apiKey: apiKey,
                        messageBytes: transaction,
                        keyType: keyType,
                        encoding: encoding)
                ).stringValue
                Logger.tee.debug("Transaction signed successfully")
                return signature
            }
        case .error:
            Logger.tee.error("Get status returned error: \(response.errorMessage ?? "Unknown error")")
            throw .generic(response.errorMessage ?? "Unknown error")
        }
    }

    public func resetState() {
        Logger.tee.debug("resetState() - Resetting TEE state, clearing queue and reloading content")
        handshakeState = .idle
        failAllQueuedRequests(with: .generic("State was reset"))
        webProxy.resetLoadedContent()
        Logger.tee.debug("TEE state reset complete")
    }

    public func load() async throws(Error) {
        Logger.tee.debug("load() called - Current handshake state: \(handshakeState)")

        switch handshakeState {
        case .inProgress:
            Logger.tee.debug("Handshake already in progress, waiting for completion")
            while case .inProgress = handshakeState {
                do {
                    try await Task.sleep(nanoseconds: 100_000_000)
                } catch {
                    Logger.tee.error("Task cancelled while waiting for handshake")
                    throw Error.generic("Task was cancelled")
                }
            }
            if case .failed(let error) = handshakeState {
                Logger.tee.error("Handshake failed with error: \(error)")
                throw error
            }
            Logger.tee.debug("Handshake completed while waiting")
            return
        case .completed:
            Logger.tee.debug("Handshake already completed, skipping load")
            return
        case .idle, .failed:
            Logger.tee.debug("Starting new handshake sequence")
            break
        }

        handshakeState = .inProgress
        Logger.tee.debug("Handshake state set to inProgress")

        do {
            Logger.tee.debug("Loading TEE URL: \(url)")
            do {
                try await webProxy.loadURL(url)
                Logger.tee.debug("TEE URL loaded successfully")
            } catch {
                Logger.tee.error("Failed to load TEE URL: \(error)")
                throw Error.urlNotAvailable
            }

            Logger.tee.debug("Starting handshake with max 3 attempts")
            try await tryHandshake(maxAttempts: 3)
            handshakeState = .completed
            Logger.tee.debug("Handshake completed successfully, processing queued requests")
            await processNextQueuedRequest()
        } catch let teeError as CrossmintTEE.Error {
            Logger.tee.error("TEE error during load: \(teeError)")
            handshakeState = .failed(teeError)
            failAllQueuedRequests(with: teeError)
            throw teeError
        } catch {
            Logger.tee.error("Generic error during load: \(error.localizedDescription)")
            let genericError = Error.generic("Handshake failed: \(error.localizedDescription)")
            handshakeState = .failed(genericError)
            failAllQueuedRequests(with: genericError)
            throw genericError
        }
    }

    private func tryHandshake(maxAttempts: Int) async throws(Error) {
        Logger.tee.debug("tryHandshake() - Attempting handshake with max \(maxAttempts) attempts")
        for attempt in 1...maxAttempts {
            do {
                Logger.tee.debug("Handshake attempt \(attempt)/\(maxAttempts)")
                try await performHandshake(timeout: 2.0)
                Logger.tee.debug("Handshake succeeded on attempt \(attempt)")
                return
            } catch CrossmintTEE.Error.timeout {
                Logger.tee.warn("Handshake timeout on attempt \(attempt)/\(maxAttempts)")
                if attempt < maxAttempts {
                    continue
                }
            } catch {
                Logger.tee.error("Handshake error on attempt \(attempt): \(error)")
                throw error
            }
        }
        Logger.tee.error("Handshake failed after \(maxAttempts) attempts")
        throw Error.handshakeFailed
    }

    private func tryGetStatus(jwt: String, maxAttempts: Int) async throws(Error) -> GetStatusResponse {
        Logger.tee.debug("tryGetStatus() - Attempting to get signer status with max \(maxAttempts) attempts")
        for attempt in 1...maxAttempts {
            do {
                Logger.tee.debug("Get status attempt \(attempt)/\(maxAttempts)")
                let response = try await getStatusResponse(jwt: jwt)
                Logger.tee.debug("Get status succeeded on attempt \(attempt) with status: \(response.status)")
                return response
            } catch Error.generic(let message) where message.contains("Failed to get status response") {
                Logger.tee.warn("Get status failed on attempt \(attempt)/\(maxAttempts): \(message)")
                if attempt < maxAttempts {
                    Logger.tee.info("Retrying get status after 500ms delay")
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    continue
                }
                Logger.tee.error("Get status exhausted all attempts")
                throw Error.generic(message)
            } catch {
                Logger.tee.error("Get status error on attempt \(attempt): \(error)")
                throw error
            }
        }
        Logger.tee.error("Get status failed after \(maxAttempts) attempts")
        throw Error.generic("Failed to get status after \(maxAttempts) attempts")
    }

    private func performHandshake(timeout: TimeInterval = 5.0) async throws(Error) {
        let randomVerificationId = randomString(length: 10)
        Logger.tee.debug("performHandshake() - Generated verification ID: \(randomVerificationId), timeout: \(timeout)s")

        do {
            Logger.tee.debug("Sending handshakeRequest to iframe")
            try await webProxy.sendMessage(
                HandshakeRequest(requestVerificationId: randomVerificationId)
            )
            Logger.tee.debug("handshakeRequest sent, waiting for handshakeResponse")

            let handshakeResponse = try await webProxy.waitForMessage(
                ofType: HandshakeResponse.self,
                timeout: timeout
            )
            Logger.tee.debug("Received handshakeResponse with verification ID: \(handshakeResponse.data.requestVerificationId)")

            Logger.tee.debug("Sending handshakeComplete to iframe")
            try await webProxy.sendMessage(
                HandshakeComplete(requestVerificationId: handshakeResponse.data.requestVerificationId)
            )
            Logger.tee.debug("handshakeComplete sent - Handshake protocol finished successfully")
        } catch WebViewError.timeout {
            Logger.tee.error("Handshake timeout after \(timeout)s")
            throw Error.timeout
        } catch {
            Logger.tee.error("Handshake failed with error: \(error)")
            throw Error.handshakeFailed
        }
    }

    private func randomString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }

    private func getStatusResponse(jwt: String) async throws(Error) -> GetStatusResponse {
        Logger.tee.debug("getStatusResponse() - Sending request:get-status to iframe")
        do {
            try await webProxy.sendMessage(GetStatusRequest(jwt: jwt, apiKey: apiKey))
            Logger.tee.debug("request:get-status sent, waiting for response:get-status (timeout: 20s)")

            let getStatusResponse = try await webProxy.waitForMessage(
                ofType: GetStatusResponse.self,
                timeout: 20.0
            )
            Logger.tee.debug("Received response:get-status - Status: \(getStatusResponse.status), SignerStatus: \(getStatusResponse.signerStatus?.rawValue ?? "nil")")

            return getStatusResponse
        } catch {
            Logger.tee.error("Failed to get status from frame. Error: \(error)")
            throw .generic("Failed to get status response")
        }
    }

    private func startOnboarding(jwt: String, authId: String) async throws(Error) -> StartOnboardingResponse {
        Logger.tee.debug("startOnboarding() - Sending request:start-onboarding to iframe with authId: \(authId)")
        do {
            try await webProxy.sendMessage(
                StartOnboardingRequest(jwt: jwt, apiKey: apiKey, authId: authId)
            )
            Logger.tee.debug("request:start-onboarding sent, waiting for response:start-onboarding (timeout: 20s)")

            let response = try await webProxy.waitForMessage(
                ofType: StartOnboardingResponse.self,
                timeout: 20.0
            )
            Logger.tee.debug("Received response:start-onboarding - Status: \(response.status)")

            return response
        } catch {
            Logger.tee.error("Failed to onboard: \(error)")
            throw .generic("Failed to start onboarding")
        }
    }

    private func validate(otpCode: String, jwt: String) async throws(Error) -> CompleteOnboardingResponse {
        Logger.tee.debug("validate() - Sending request:complete-onboarding to iframe with encrypted OTP")
        do {
            try await webProxy.sendMessage(
                CompleteOnboardingRequest(jwt: jwt, apiKey: apiKey, otp: otpCode)
            )
            Logger.tee.debug("request:complete-onboarding sent, waiting for response:complete-onboarding (timeout: 20s)")

            let response = try await webProxy.waitForMessage(
                ofType: CompleteOnboardingResponse.self,
                timeout: 20.0
            )
            Logger.tee.debug("Received response:complete-onboarding - Status: \(response.status)")

            return response
        } catch {
            Logger.tee.error("Failed to validate OTP: \(error)")
            throw .generic("Failed to complete onboarding")
        }
    }

    private func getAuthId() throws(Error) -> String {
        guard let email = email else {
            throw .authMissing
        }
        return "email:\(email)"
    }

    private func waitForOTP() async throws(Error) -> String {
        Logger.tee.debug("waitForOTP() - Waiting for user to provide OTP code")
        do {
            let otp = try await withCheckedThrowingContinuation { continuation in
                self.otpContinuation?.resume(throwing: Error.newerSignatureRequested)
                self.otpContinuation = continuation
                self.isOTPRequired = true
            }
            Logger.tee.debug("OTP received from user")
            return otp
        } catch CrossmintTEE.Error.userCancelled {
            Logger.tee.warn("User cancelled OTP input")
            throw .userCancelled
        } catch Error.newerSignatureRequested {
            Logger.tee.warn("Newer signature requested, cancelling OTP wait")
            throw .newerSignatureRequested
        } catch {
            Logger.tee.error("Unknown error waiting for OTP: \(error.localizedDescription)")
            throw .generic("Unknown error happened: \(error.localizedDescription)")
        }
    }

    private func sign(
        _ request: NonCustodialSignRequest
    ) async throws(Error) -> String {
        Logger.tee.debug("sign() - Sending request:sign to iframe with keyType: \(request.data.data.keyType), encoding: \(request.data.data.encoding)")
        do {
            _ = try await webProxy.sendMessage(request)
            Logger.tee.debug("request:sign sent, waiting for response:sign (timeout: 10s)")

            let response = try await webProxy.waitForMessage(
                ofType: NonCustodialSignResponse.self,
                timeout: 10.0
            )
            Logger.tee.debug("Received response:sign - Status: \(response.status)")

            guard let bytes = response.signature?.bytes, !bytes.isEmpty else {
                Logger.tee.error("Error signing: frame returned empty signature")
                throw Error.invalidSignature
            }
            Logger.tee.debug("Sign completed successfully with signature bytes length: \(bytes.count)")
            return bytes
        } catch {
            Logger.tee.error("Error signing: \(error)")
            if let crossmintError = error as? CrossmintTEE.Error {
                throw crossmintError
            }
            throw .generic("Failed to complete signing")
        }
    }

    public func provideOTP(_ code: String) {
        Logger.tee.debug("provideOTP() - User provided OTP code")
        otpContinuation?.resume(returning: code)
        otpContinuation = nil
        isOTPRequired = false
    }

    public func cancelOTP() {
        Logger.tee.debug("cancelOTP() - User cancelled OTP input")
        otpContinuation?.resume(throwing: CrossmintTEE.Error.userCancelled)
        otpContinuation = nil
        isOTPRequired = false
    }

    @discardableResult
    public static func start(
        auth: AuthManager,
        webProxy: WebViewCommunicationProxy,
        apiKey: String,
        isProductionEnvironment: Bool
    ) -> CrossmintTEE {
        let instance = CrossmintTEE(
            auth: auth,
            webProxy: webProxy,
            apiKey: apiKey,
            isProductionEnvironment: isProductionEnvironment
        )
        CrossmintTEE.shared = instance
        return instance
    }
}

extension CrossmintTEE {
    fileprivate func queueSignRequest(
        transaction: String,
        keyType: String,
        encoding: String
    ) async throws(Error) -> String {
        let requestId = UUID()
        Logger.tee.debug("queueSignRequest() - Queueing sign request \(requestId), current queue size: \(signRequestQueue.count)")

        do {
            return try await withTaskCancellationHandler {
                try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<String, Swift.Error>) in
                    let timeoutTask = createTimeoutTask(requestId: requestId)

                    let pendingRequest = PendingSignRequest(
                        id: requestId,
                        transaction: transaction,
                        keyType: keyType,
                        encoding: encoding,
                        callback: { result in
                            switch result {
                            case .success(let value):
                                continuation.resume(returning: value)
                            case .failure(let error):
                                continuation.resume(throwing: error)
                            }
                        },
                        timeoutTask: timeoutTask
                    )
                    signRequestQueue.append(pendingRequest)
                    Logger.tee.debug("Sign request \(requestId) added to queue, new queue size: \(signRequestQueue.count)")
                }
            } onCancel: {
                Task { @MainActor in
                    Logger.tee.warn("Sign request \(requestId) was cancelled")
                    self.resumeSignRequest(id: requestId, with: .failure(.generic("Task was cancelled")))
                }
            }
        } catch let error as CrossmintTEE.Error {
            Logger.tee.error("Sign request \(requestId) failed with error: \(error)")
            throw error
        } catch {
            Logger.tee.error("Sign request \(requestId) failed with unexpected error: \(error.localizedDescription)")
            throw .generic("Unexpected error: \(error.localizedDescription)")
        }
    }

    fileprivate func createTimeoutTask(requestId: UUID) -> Task<Void, Never> {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            if !Task.isCancelled {
                resumeSignRequest(id: requestId, with: .failure(.queueTimeout))
            }
        }
    }

    fileprivate func resumeSignRequest(
        id: UUID,
        with result: Result<String, CrossmintTEE.Error>
    ) {
        guard let index = signRequestQueue.firstIndex(where: { $0.id == id }) else {
            return
        }

        let request = signRequestQueue.remove(at: index)
        request.timeoutTask.cancel()
        request.callback(result)
    }

    fileprivate func processNextQueuedRequest() async {
        guard !signRequestQueue.isEmpty else {
            Logger.tee.debug("processNextQueuedRequest() - Queue is empty, nothing to process")
            return
        }
        guard case .completed = handshakeState else {
            Logger.tee.warn("processNextQueuedRequest() - Handshake not completed, cannot process queue")
            return
        }

        let request = signRequestQueue.removeFirst()
        Logger.tee.debug("processNextQueuedRequest() - Processing request \(request.id), remaining queue size: \(signRequestQueue.count)")
        request.timeoutTask.cancel()

        do {
            let result = try await executeSignTransaction(
                transaction: request.transaction,
                keyType: request.keyType,
                encoding: request.encoding
            )
            Logger.tee.debug("Request \(request.id) completed successfully")
            request.callback(.success(result))
        } catch {
            Logger.tee.error("Request \(request.id) failed with error: \(error)")
            request.callback(.failure(error))
        }

        await processNextQueuedRequest()
    }

    fileprivate func failAllQueuedRequests(with error: CrossmintTEE.Error) {
        let queueSize = signRequestQueue.count
        Logger.tee.warn("failAllQueuedRequests() - Failing \(queueSize) queued requests with error: \(error)")
        while !signRequestQueue.isEmpty {
            let request = signRequestQueue.removeFirst()
            Logger.tee.warn("Failing request \(request.id)")
            request.timeoutTask.cancel()
            request.callback(.failure(error))
        }
        Logger.tee.debug("All queued requests failed")
    }
}
