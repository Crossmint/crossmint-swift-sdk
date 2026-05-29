import Foundation
@testable import CrossmintAuth

// @unchecked Sendable: safe because each test creates a fresh instance and calls are sequential via actor isolation
final class MockAuthService: AuthService, @unchecked Sendable {

    // MARK: - Call tracking
    var validateEmailCallCount = 0
    var validateTokenCallCount = 0
    var refreshJWTCallCount = 0
    var logoutCallCount = 0

    // MARK: - Configurable outcomes
    var validateEmailResponse = ValidateEmailResponse(emailId: "test-email-id")
    var validateTokenResponse = ValidateTokenResponse(callbackUrl: "", oneTimeSecret: "test-secret")
    var refreshJWTResponse = RefreshJWTResponse(
        jwt: "test-jwt",
        refresh: .init(secret: "test-secret", expiresAt: Date().addingTimeInterval(3600)),
        user: .init(id: "test-id", email: "user@example.com")
    )
    var validateEmailError: AuthError?
    var validateTokenError: AuthError?
    var refreshJWTError: AuthError?

    // MARK: - Protocol implementation
    func validateEmail(_ request: ValidateEmailRequest) async throws(AuthError) -> ValidateEmailResponse {
        validateEmailCallCount += 1
        if let error = validateEmailError { throw error }
        return validateEmailResponse
    }

    func validateToken(_ request: ValidateTokenRequest) async throws(AuthError) -> ValidateTokenResponse {
        validateTokenCallCount += 1
        if let error = validateTokenError { throw error }
        return validateTokenResponse
    }

    func refreshJWT(_ request: RefreshJWTRequest) async throws(AuthError) -> RefreshJWTResponse {
        refreshJWTCallCount += 1
        if let error = refreshJWTError { throw error }
        return refreshJWTResponse
    }

    func logout(_ request: LogoutRequest) async throws(AuthError) {
        logoutCallCount += 1
    }
}
