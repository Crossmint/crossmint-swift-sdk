/// The authenticated session returned after a successful OTP verification.
public struct AuthSession: Sendable {
    /// A short-lived JWT for authorizing requests to Crossmint APIs.
    public let jwt: String
    /// Details about the authenticated user.
    public let user: AuthUser
}
