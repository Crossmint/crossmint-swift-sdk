/// Standalone authentication client for apps that manage auth independently of wallet operations.
///
/// Access via ``CrossmintSDK/authClient``. For most apps the built-in email OTP flow through
/// ``CrossmintAuthManager`` is sufficient; use `AuthClient` when you need explicit control over
/// the OTP lifecycle (e.g. custom UI, headless flows).
///
/// ## Example
/// ```swift
/// let client = CrossmintSDK.shared.authClient
///
/// let request = try await client.sendOTP(to: "user@example.com")
/// // ... show OTP input to user ...
/// let session = try await client.verifyOTP(code: userInput, requestId: request.requestId)
/// print("Signed in:", session.user.email)
/// ```
public protocol AuthClient: Sendable {
    /// Sends an OTP to the given email address.
    ///
    /// - Returns: An ``OTPRequest`` whose ``OTPRequest/requestId`` is required by ``verifyOTP(code:requestId:)``.
    func sendOTP(to email: String) async throws(AuthError) -> OTPRequest

    /// Validates the OTP and establishes a session.
    ///
    /// - Parameters:
    ///   - code: The code the user entered.
    ///   - requestId: The value from the ``OTPRequest`` returned by ``sendOTP(to:)``.
    func verifyOTP(code: String, requestId: String) async throws(AuthError) -> AuthSession

    /// Invalidates the current session.
    func logout() async
}
