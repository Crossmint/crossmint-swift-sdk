import CrossmintService
import Foundation
import Http

public struct StartOnboardingInput: Codable, Sendable {
    public let authId: String
    public let deviceId: String
    public let encryptionContext: EncryptionContext

    public init(authId: String, deviceId: String, encryptionContext: EncryptionContext) {
        self.authId = authId
        self.deviceId = deviceId
        self.encryptionContext = encryptionContext
    }
}

public struct EncryptionContext: Codable, Sendable {
    public let publicKey: String

    public init(publicKey: String) {
        self.publicKey = publicKey
    }
}

public enum OnboardingEndpoint {
    case startOnboarding(input: StartOnboardingInput, authData: AuthData)

    var endpoint: Endpoint {
        switch self {
        case .startOnboarding(let input, let authData):
            let body = try? JSONEncoder().encode(input)
            return Endpoint(
                path: "/ncs/v1/signers/start-onboarding",
                method: .post,
                headers: [
                    "Content-Type": "application/json",
                    "Authorization": "Bearer \(authData.jwt)",
                    "x-api-key": authData.apiKey
                ],
                body: body
            )
        }
    }
}

public enum OnboardingError: Error, Equatable, ServiceError {
    case startOnboardingFailed(String)
    case deviceNotReady
    case invalidAuthData

    public static func fromServiceError(_ error: CrossmintServiceError) -> OnboardingError {
        .startOnboardingFailed(error.errorMessage)
    }

    public static func fromNetworkError(_ error: NetworkError) -> OnboardingError {
        let message = error.serviceErrorMessage ?? error.localizedDescription
        return .startOnboardingFailed(message)
    }

    public var errorMessage: String {
        switch self {
        case .startOnboardingFailed(let message):
            return "Failed to start onboarding: \(message)"
        case .deviceNotReady:
            return "Device is not ready for onboarding"
        case .invalidAuthData:
            return "Invalid authentication data"
        }
    }
}

public enum SignerStatus: String, Sendable {
    case ready
    case newDevice = "new-device"
}

public struct StartOnboardingResult: Sendable {
    public let signerStatus: SignerStatus

    public init(signerStatus: SignerStatus) {
        self.signerStatus = signerStatus
    }
}

public actor OnboardingService {
    private let service: CrossmintService
    private let deviceService: DeviceService

    public init(service: CrossmintService, deviceService: DeviceService) {
        self.service = service
        self.deviceService = deviceService
    }

    public func startOnboarding(
        authId: String,
        authData: AuthData
    ) async throws -> StartOnboardingResult {
        let deviceId = try await deviceService.getId()
        let publicKey = try await deviceService.getSerializedIdentityPublicKey()

        let input = StartOnboardingInput(
            authId: authId,
            deviceId: deviceId,
            encryptionContext: EncryptionContext(publicKey: publicKey)
        )

        let endpoint = OnboardingEndpoint.startOnboarding(input: input, authData: authData)

        do {
            try await service.executeRequest(
                endpoint.endpoint,
                errorType: OnboardingError.self
            )
            return StartOnboardingResult(signerStatus: .newDevice)
        } catch let error as OnboardingError {
            throw error
        } catch {
            throw OnboardingError.startOnboardingFailed(error.localizedDescription)
        }
    }
}
