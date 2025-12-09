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
        if case .completed = handshakeState {
            return try await executeSignTransaction(
                transaction: transaction,
                keyType: keyType,
                encoding: encoding
            )
        }

        switch handshakeState {
        case .idle, .failed:
            handshakeState = .idle
            Task {
                try? await load()
            }
        case .inProgress, .completed:
            break
        }

        return try await queueSignRequest(transaction: transaction, keyType: keyType, encoding: encoding)
    }

    private func executeSignTransaction(
        transaction: String,
        keyType: String,
        encoding: String
    ) async throws(Error) -> String {
        guard let jwt = await auth.jwt else {
            Logger.tee.warn("JWT is missing, cannot proceed with signing")
            throw .jwtRequired
        }

        let response = try await self.tryGetStatus(jwt: jwt, maxAttempts: 3)
        switch response.status {
        case .success:
            guard let signerStatus = response.signerStatus else {
                Logger.tee.error("signer.getStatus.error", attributes: [
                    "error": "Status response missing signerStatus field"
                ])
                throw .generic("Signer status missing from response")
            }
            switch signerStatus {
            case .newDevice:
                let onboardingResponse = try await startOnboarding(
                    jwt: jwt,
                    authId: try getAuthId()
                )

                guard onboardingResponse.status == .success else {
                    Logger.tee.error("signer.onboarding.error", attributes: [
                        "error": onboardingResponse.errorMessage ?? "Unknown error"
                    ])
                    throw .generic("Invalid NCS status")
                }

                let otpCode: String = try await waitForOTP()
                _ = try await validate(otpCode: otpCode, jwt: jwt)

                return try await sign(
                    .init(
                        jwt: jwt,
                        apiKey: apiKey,
                        messageBytes: transaction,
                        keyType: keyType,
                        encoding: encoding)
                ).stringValue
            case .ready:
                return try await sign(
                    .init(
                        jwt: jwt,
                        apiKey: apiKey,
                        messageBytes: transaction,
                        keyType: keyType,
                        encoding: encoding)
                ).stringValue
            }
        case .error:
            Logger.tee.error("signer.getStatus.error", attributes: [
                "error": response.errorMessage ?? "Unknown error"
            ])
            throw .generic(response.errorMessage ?? "Unknown error")
        }
    }

    public func resetState() {
        Logger.tee.debug("signer.resetState.start")
        handshakeState = .idle
        failAllQueuedRequests(with: .generic("State was reset"))
        webProxy.resetLoadedContent()
        Logger.tee.debug("signer.resetState.success")
    }

    public func load() async throws(Error) {
        switch handshakeState {
        case .inProgress:
            while case .inProgress = handshakeState {
                do {
                    try await Task.sleep(nanoseconds: 100_000_000)
                } catch {
                    Logger.tee.error("signer.load.error", attributes: [
                        "error": "Task was cancelled"
                    ])
                    throw Error.generic("Task was cancelled")
                }
            }
            if case .failed(let error) = handshakeState {
                throw error
            }
            return
        case .completed:
            return
        case .idle, .failed:
            break
        }

        handshakeState = .inProgress

        do {
            do {
                try await webProxy.loadURL(url)
            } catch {
                Logger.tee.error("signer.load.error", attributes: [
                    "error": "Failed to load TEE URL: \(error)"
                ])
                throw Error.urlNotAvailable
            }

            try await tryHandshake(maxAttempts: 3)
            handshakeState = .completed
            await processNextQueuedRequest()
        } catch let teeError as CrossmintTEE.Error {
            handshakeState = .failed(teeError)
            failAllQueuedRequests(with: teeError)
            throw teeError
        } catch {
            let genericError = Error.generic("Handshake failed: \(error.localizedDescription)")
            handshakeState = .failed(genericError)
            failAllQueuedRequests(with: genericError)
            throw genericError
        }
    }

    private func tryHandshake(maxAttempts: Int) async throws(Error) {
        for attempt in 1...maxAttempts {
            do {
                try await performHandshake(timeout: 2.0)
                return
            } catch CrossmintTEE.Error.timeout {
                if attempt < maxAttempts {
                    Logger.tee.info("signer.handshake.retry", attributes: [
                        "handshake.attempt": "\(attempt)",
                        "handshake.maxAttempts": "\(maxAttempts)"
                    ])
                    continue
                }
            } catch {
                throw error
            }
        }
        Logger.tee.error("signer.handshake.error", attributes: [
            "error": "Failed after \(maxAttempts) attempts"
        ])
        throw Error.handshakeFailed
    }

    private func tryGetStatus(jwt: String, maxAttempts: Int) async throws(Error) -> GetStatusResponse {
        for attempt in 1...maxAttempts {
            do {
                let response = try await getStatusResponse(jwt: jwt)
                return response
            } catch Error.generic(let message) where message.contains("Failed to get status response") {
                if attempt < maxAttempts {
                    Logger.tee.info("signer.getStatus.retry", attributes: [
                        "signer.attempt": "\(attempt)",
                        "signer.maxAttempts": "\(maxAttempts)",
                        "signer.delayMs": "500"
                    ])
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    continue
                }
                Logger.tee.error("signer.getStatus.error", attributes: [
                    "error": message
                ])
                throw Error.generic(message)
            } catch {
                Logger.tee.error("signer.getStatus.error", attributes: [
                    "error": "\(error)"
                ])
                throw error
            }
        }
        Logger.tee.error("signer.getStatus.error", attributes: [
            "error": "Failed after \(maxAttempts) attempts"
        ])
        throw Error.generic("Failed to get status after \(maxAttempts) attempts")
    }

    private func performHandshake(timeout: TimeInterval = 5.0) async throws(Error) {
        let randomVerificationId = randomString(length: 10)
        Logger.tee.debug("signer.handshake.start", attributes: [
            "handshake.verificationId": randomVerificationId,
            "handshake.timeout": "\(timeout)"
        ])

        do {
            try await webProxy.sendMessage(
                HandshakeRequest(requestVerificationId: randomVerificationId)
            )

            let handshakeResponse = try await webProxy.waitForMessage(
                ofType: HandshakeResponse.self,
                timeout: timeout
            )

            try await webProxy.sendMessage(
                HandshakeComplete(requestVerificationId: handshakeResponse.data.requestVerificationId)
            )

            Logger.tee.debug("signer.handshake.success", attributes: [
                "handshake.verificationId": handshakeResponse.data.requestVerificationId
            ])
        } catch WebViewError.timeout {
            Logger.tee.error("signer.handshake.error", attributes: [
                "error": "Timeout after \(timeout)s"
            ])
            throw Error.timeout
        } catch {
            Logger.tee.error("signer.handshake.error", attributes: [
                "error": "\(error)"
            ])
            throw Error.handshakeFailed
        }
    }

    private func randomString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }

    private func getStatusResponse(jwt: String) async throws(Error) -> GetStatusResponse {
        Logger.tee.debug("signer.getStatus.start")

        do {
            try await webProxy.sendMessage(GetStatusRequest(jwt: jwt, apiKey: apiKey))

            let getStatusResponse = try await webProxy.waitForMessage(
                ofType: GetStatusResponse.self,
                timeout: 20.0
            )

            Logger.tee.debug("signer.getStatus.success", attributes: [
                "signer.status": "\(getStatusResponse.status)",
                "signer.signerStatus": getStatusResponse.signerStatus?.rawValue ?? "nil"
            ])

            return getStatusResponse
        } catch {
            Logger.tee.error("signer.getStatus.error", attributes: [
                "error": "\(error)"
            ])
            throw .generic("Failed to get status response")
        }
    }

    private func startOnboarding(jwt: String, authId: String) async throws(Error) -> StartOnboardingResponse {
        Logger.tee.debug("signer.onboarding.start", attributes: [
            "onboarding.authId": authId
        ])

        do {
            try await webProxy.sendMessage(
                StartOnboardingRequest(jwt: jwt, apiKey: apiKey, authId: authId)
            )

            let response = try await webProxy.waitForMessage(
                ofType: StartOnboardingResponse.self,
                timeout: 20.0
            )

            Logger.tee.debug("signer.onboarding.success", attributes: [
                "onboarding.status": "\(response.status)"
            ])

            return response
        } catch {
            Logger.tee.error("signer.onboarding.error", attributes: [
                "error": "\(error)"
            ])
            throw .generic("Failed to start onboarding")
        }
    }

    private func validate(otpCode: String, jwt: String) async throws(Error) -> CompleteOnboardingResponse {
        Logger.tee.debug("signer.onboarding.complete.start")

        do {
            try await webProxy.sendMessage(
                CompleteOnboardingRequest(jwt: jwt, apiKey: apiKey, otp: otpCode)
            )

            let response = try await webProxy.waitForMessage(
                ofType: CompleteOnboardingResponse.self,
                timeout: 20.0
            )

            Logger.tee.debug("signer.onboarding.complete.success", attributes: [
                "onboarding.status": "\(response.status)"
            ])

            return response
        } catch {
            Logger.tee.error("signer.onboarding.complete.error", attributes: [
                "error": "\(error)"
            ])
            throw .generic("Failed to complete onboarding")
        }
    }

    private func getAuthId() throws(Error) -> String {
        guard let email = email else {
            Logger.tee.error("signer.getAuthId.error", attributes: [
                "error": "Email is missing"
            ])
            throw .authMissing
        }
        return "email:\(email)"
    }

    private func waitForOTP() async throws(Error) -> String {
        Logger.tee.debug("signer.otp.wait")
        do {
            let otp = try await withCheckedThrowingContinuation { continuation in
                self.otpContinuation?.resume(throwing: Error.newerSignatureRequested)
                self.otpContinuation = continuation
                self.isOTPRequired = true
            }
            Logger.tee.debug("signer.otp.received")
            return otp
        } catch CrossmintTEE.Error.userCancelled {
            Logger.tee.warn("signer.otp.cancelled")
            throw .userCancelled
        } catch Error.newerSignatureRequested {
            Logger.tee.warn("signer.otp.superseded")
            throw .newerSignatureRequested
        } catch {
            Logger.tee.error("signer.otp.error", attributes: [
                "error": "\(error.localizedDescription)"
            ])
            throw .generic("Unknown error happened: \(error.localizedDescription)")
        }
    }

    private func sign(
        _ request: NonCustodialSignRequest
    ) async throws(Error) -> String {
        Logger.tee.debug("signer.sign.start", attributes: [
            "sign.keyType": request.data.data.keyType,
            "sign.encoding": request.data.data.encoding
        ])

        do {
            _ = try await webProxy.sendMessage(request)

            let response = try await webProxy.waitForMessage(
                ofType: NonCustodialSignResponse.self,
                timeout: 10.0
            )

            guard let bytes = response.signature?.bytes, !bytes.isEmpty else {
                Logger.tee.error("signer.sign.error", attributes: [
                    "error": "Empty signature returned from frame"
                ])
                throw Error.invalidSignature
            }

            Logger.tee.debug("signer.sign.success", attributes: [
                "sign.signatureLength": "\(bytes.count)"
            ])
            return bytes
        } catch {
            Logger.tee.error("signer.sign.error", attributes: [
                "error": "\(error)"
            ])
            if let crossmintError = error as? CrossmintTEE.Error {
                throw crossmintError
            }
            throw .generic("Failed to complete signing")
        }
    }

    public func provideOTP(_ code: String) {
        Logger.tee.debug("signer.otp.provided")
        otpContinuation?.resume(returning: code)
        otpContinuation = nil
        isOTPRequired = false
    }

    public func cancelOTP() {
        Logger.tee.debug("signer.otp.userCancelled")
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
        Logger.tee.debug("signer.queue.enqueue", attributes: [
            "queue.requestId": requestId.uuidString,
            "queue.size": "\(signRequestQueue.count)"
        ])

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
                }
            } onCancel: {
                Task { @MainActor in
                    Logger.tee.warn("signer.queue.cancelled", attributes: [
                        "queue.requestId": requestId.uuidString
                    ])
                    self.resumeSignRequest(id: requestId, with: .failure(.generic("Task was cancelled")))
                }
            }
        } catch let error as CrossmintTEE.Error {
            Logger.tee.error("signer.queue.error", attributes: [
                "queue.requestId": requestId.uuidString,
                "error": "\(error)"
            ])
            throw error
        } catch {
            Logger.tee.error("signer.queue.error", attributes: [
                "queue.requestId": requestId.uuidString,
                "error": "\(error.localizedDescription)"
            ])
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
            Logger.tee.warn("signer.queue.resume.error", attributes: [
                "queue.requestId": id.uuidString,
                "error": "Request not found in queue"
            ])
            return
        }

        let request = signRequestQueue.remove(at: index)
        request.timeoutTask.cancel()
        request.callback(result)
    }

    fileprivate func processNextQueuedRequest() async {
        guard !signRequestQueue.isEmpty else {
            return
        }
        guard case .completed = handshakeState else {
            Logger.tee.warn("signer.queue.process.error", attributes: [
                "error": "Handshake not completed"
            ])
            return
        }

        let request = signRequestQueue.removeFirst()
        Logger.tee.debug("signer.queue.process", attributes: [
            "queue.requestId": request.id.uuidString,
            "queue.remainingSize": "\(signRequestQueue.count)"
        ])
        request.timeoutTask.cancel()

        do {
            let result = try await executeSignTransaction(
                transaction: request.transaction,
                keyType: request.keyType,
                encoding: request.encoding
            )
            Logger.tee.debug("signer.queue.process.success", attributes: [
                "queue.requestId": request.id.uuidString
            ])
            request.callback(.success(result))
        } catch {
            Logger.tee.error("signer.queue.process.error", attributes: [
                "queue.requestId": request.id.uuidString,
                "error": "\(error)"
            ])
            request.callback(.failure(error))
        }

        await processNextQueuedRequest()
    }

    fileprivate func failAllQueuedRequests(with error: CrossmintTEE.Error) {
        guard !signRequestQueue.isEmpty else {
            return
        }

        let queueSize = signRequestQueue.count
        Logger.tee.warn("signer.queue.failAll", attributes: [
            "queue.count": "\(queueSize)",
            "error": "\(error)"
        ])

        while !signRequestQueue.isEmpty {
            let request = signRequestQueue.removeFirst()
            request.timeoutTask.cancel()
            request.callback(.failure(error))
        }
    }
}
