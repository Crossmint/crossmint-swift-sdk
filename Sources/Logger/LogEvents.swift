import Foundation

/// Centralized log event names for structured logging
/// All event names follow the pattern: {component}.{operation}.{status}
public enum LogEvents {

    // MARK: - Handshake Events

    /// Handshake operation started
    public static let handshakeStart = "signer.handshake.start"

    /// Handshake completed successfully
    public static let handshakeSuccess = "signer.handshake.success"

    /// Handshake failed
    public static let handshakeError = "signer.handshake.error"

    /// Retrying handshake after failure
    public static let handshakeRetry = "signer.handshake.retry"

    // MARK: - GetStatus Events

    /// Requesting signer status
    public static let getStatusStart = "signer.getStatus.start"

    /// Status retrieved successfully
    public static let getStatusSuccess = "signer.getStatus.success"

    /// Failed to get status
    public static let getStatusError = "signer.getStatus.error"

    /// Retrying status request
    public static let getStatusRetry = "signer.getStatus.retry"

    // MARK: - Onboarding Events

    /// Starting onboarding flow
    public static let onboardingStart = "signer.onboarding.start"

    /// Onboarding started successfully
    public static let onboardingSuccess = "signer.onboarding.success"

    /// Failed to start onboarding
    public static let onboardingError = "signer.onboarding.error"

    /// Starting OTP validation
    public static let onboardingCompleteStart = "signer.onboarding.complete.start"

    /// OTP validated successfully
    public static let onboardingCompleteSuccess = "signer.onboarding.complete.success"

    /// OTP validation failed
    public static let onboardingCompleteError = "signer.onboarding.complete.error"

    // MARK: - Sign Events

    /// Starting signature request
    public static let signStart = "signer.sign.start"

    /// Signature completed successfully
    public static let signSuccess = "signer.sign.success"

    /// Signature failed
    public static let signError = "signer.sign.error"

    // MARK: - Queue Events

    /// Request added to queue
    public static let queueEnqueue = "signer.queue.enqueue"

    /// Request cancelled
    public static let queueCancelled = "signer.queue.cancelled"

    /// Queue error
    public static let queueError = "signer.queue.error"

    /// Processing queued request
    public static let queueProcess = "signer.queue.process"

    /// Request processed successfully
    public static let queueProcessSuccess = "signer.queue.process.success"

    /// Processing failed
    public static let queueProcessError = "signer.queue.process.error"

    /// Failing all queued requests
    public static let queueFailAll = "signer.queue.failAll"

    /// Failed to resume request
    public static let queueResumeError = "signer.queue.resume.error"

    // MARK: - OTP Events

    /// Waiting for user OTP input
    public static let otpWait = "signer.otp.wait"

    /// OTP received from user
    public static let otpReceived = "signer.otp.received"

    /// User provided OTP
    public static let otpProvided = "signer.otp.provided"

    /// User cancelled OTP input
    public static let otpUserCancelled = "signer.otp.userCancelled"

    /// OTP wait cancelled
    public static let otpCancelled = "signer.otp.cancelled"

    /// Newer signature requested
    public static let otpSuperseded = "signer.otp.superseded"

    /// OTP error
    public static let otpError = "signer.otp.error"

    // MARK: - State Management Events

    /// Resetting TEE state
    public static let resetStateStart = "signer.resetState.start"

    /// State reset complete
    public static let resetStateSuccess = "signer.resetState.success"

    /// Error loading TEE
    public static let loadError = "signer.load.error"

    /// Missing email for authId
    public static let getAuthIdError = "signer.getAuthId.error"
}
