//
//  MockAuthService.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 6/1/26.
//

import Foundation
@testable import CrossmintAuth

final class MockAuthService: AuthService, @unchecked Sendable {

    // MARK: - Call tracking
    var validateEmailCallCount = 0
    var validateEmailLastRequest: ValidateEmailRequest?
    var validateTokenCallCount = 0
    var validateTokenLastRequest: ValidateTokenRequest?
    var refreshJWTCallCount = 0
    var refreshJWTLastRequest: RefreshJWTRequest?
    var logoutCallCount = 0
    var logoutLastRequest: LogoutRequest?

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
        validateEmailLastRequest = request
        if let error = validateEmailError { throw error }
        return validateEmailResponse
    }

    func validateToken(_ request: ValidateTokenRequest) async throws(AuthError) -> ValidateTokenResponse {
        validateTokenCallCount += 1
        validateTokenLastRequest = request
        if let error = validateTokenError { throw error }
        return validateTokenResponse
    }

    func refreshJWT(_ request: RefreshJWTRequest) async throws(AuthError) -> RefreshJWTResponse {
        refreshJWTCallCount += 1
        refreshJWTLastRequest = request
        if let error = refreshJWTError { throw error }
        return refreshJWTResponse
    }

    func logout(_ request: LogoutRequest) async throws(AuthError) {
        logoutCallCount += 1
        logoutLastRequest = request
    }
}
