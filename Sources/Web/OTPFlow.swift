import Foundation

/// Encapsulates a pending OTP authentication challenge.
///
/// Passed to the `onAuthRequired` closure on ``WalletSigner/email(_:onAuthRequired:)`` when the
/// wallet operation requires the user to prove ownership of the associated email address. Present
/// UI that lets the user enter the code, then call ``verifyOTP(_:)`` to complete authentication or
/// ``cancel()`` to abort the operation.
///
/// ```swift
/// WalletSigner.email(email) { flow in
///     // show your OTP sheet
///     self.pendingOTPFlow = flow
/// }
/// ```
public struct OTPFlow: Sendable, Identifiable {
    /// The email address the OTP was sent to.
    public let email: String

    /// Requests a new OTP to be sent to the user. Call this when the user taps "Resend".
    public let sendOTP: @Sendable () async throws -> Void

    /// Submits the code the user entered. Throws if the code is incorrect or the flow has already completed.
    public let verifyOTP: @Sendable (_ code: String) async throws -> Void

    /// Cancels the authentication challenge and fails the pending wallet operation.
    public let cancel: @Sendable () -> Void

    /// A unique identifier for this flow instance.
    public let id = UUID()
}
