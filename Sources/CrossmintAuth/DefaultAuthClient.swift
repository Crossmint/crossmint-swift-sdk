import Utils

public actor DefaultAuthClient: AuthClient {
    private let authService: AuthService
    private let authManager: CrossmintAuthManager
    private var pendingEmailsByRequestId: [String: String] = [:]

    public init(authService: AuthService, authManager: CrossmintAuthManager) {
        self.authService = authService
        self.authManager = authManager
    }

    public func sendOTP(to email: String) async throws(AuthError) -> OTPRequest {
        let normalizedEmail = normalizeEmail(email)
        guard isValidEmail(normalizedEmail) else {
            throw AuthError.generic("Invalid email address")
        }
        let response = try await authService.validateEmail(ValidateEmailRequest(email: normalizedEmail))
        pendingEmailsByRequestId[response.emailId] = normalizedEmail
        return OTPRequest(requestId: response.emailId)
    }

    public func verifyOTP(code: String, requestId: String) async throws(AuthError) -> AuthSession {
        guard let email = pendingEmailsByRequestId[requestId] else {
            throw AuthError.generic("No pending OTP for the provided requestId")
        }
        let tokenResponse = try await authService.validateToken(
            ValidateTokenRequest(email: email, token: code, emailID: requestId)
        )
        try await authManager.establishSession(oneTimeSecret: tokenResponse.oneTimeSecret)
        guard let jwt = await authManager.jwt else {
            throw AuthError.generic("Session could not be established")
        }
        guard let userEmail = await authManager.email else {
            throw AuthError.generic("Session could not be established")
        }
        pendingEmailsByRequestId.removeValue(forKey: requestId)
        return AuthSession(jwt: jwt, user: AuthUser(email: userEmail))
    }

    public func logout() async {
        try? await authManager.logout()
        pendingEmailsByRequestId.removeAll()
    }
}
