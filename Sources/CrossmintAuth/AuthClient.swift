public protocol AuthClient: Sendable {
    func sendOTP(to email: String) async throws(AuthError) -> OTPRequest
    func verifyOTP(code: String, requestId: String) async throws(AuthError) -> AuthSession
    func logout() async
}

public struct OTPRequest: Sendable {
    public let requestId: String
}

public struct AuthSession: Sendable {
    public let jwt: String
    public let user: AuthUser
}

public struct AuthUser: Sendable {
    public let email: String
}
