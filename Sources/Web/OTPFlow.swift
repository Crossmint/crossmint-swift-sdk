import Foundation

/// Encapsulates a pending OTP authentication challenge.
///
/// Passed to the `onAuthRequired` closure on ``WalletSigner/email(_:onAuthRequired:)`` when the
/// wallet operation requires the user to prove ownership of the associated email address.
/// Call ``verifyOTP(_:)`` with the code the user enters to complete authentication,
/// or ``cancel()`` to abort the pending wallet operation.
public struct OTPFlow: Sendable, Identifiable {
    /// The email address the OTP was sent to.
    public let email: String

    /// Triggers a new OTP to be sent to the same email address.
    public let sendOTP: @Sendable () async throws -> Void

    /// Submits the code the user entered. Throws if the code is incorrect or the flow has already completed.
    public let verifyOTP: @Sendable (_ code: String) async throws -> Void

    /// Cancels the authentication challenge and fails the pending wallet operation.
    public let cancel: @Sendable () -> Void

    /// A unique identifier for this flow instance.
    public let id = UUID()
}
