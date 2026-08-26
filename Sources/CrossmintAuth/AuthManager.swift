import CrossmintService
import Foundation
import Logger

/// Provides the current user's JWT to the SDK for authenticated requests.
///
/// The built-in implementation is ``CrossmintAuthManager``, which handles email OTP sessions.
/// Provide a custom conformance to integrate an existing auth system — only ``jwt`` and
/// ``setJWT(_:)`` are required.
public protocol AuthManager: Sendable {
    /// The current session JWT, or `nil` when the user is not authenticated.
    var jwt: String? { get async }

    /// Injects an externally-obtained JWT into the SDK session.
    func setJWT(_ jwt: String) async
}

public enum AuthManagerError: CrossmintError, Equatable {
    case unknown(String)
    case serviceError(String)
    /// The caller supplied a value that failed validation (e.g. an empty OTP code).
    case invalidInput(String)
    /// The email address is not a valid format.
    case invalidEmail
    /// ``CrossmintAuthManager/confirmEmailOtp(email:code:)`` was called before ``CrossmintAuthManager/sendEmailOtp(email:)``.
    case noPendingOTP

    public var code: String {
        switch self {
        case .unknown: "AUTH_MANAGER_ERROR"
        case .serviceError: "AUTH_SERVICE_ERROR"
        case .invalidInput: "INVALID_INPUT"
        case .invalidEmail: "INVALID_EMAIL"
        case .noPendingOTP: "NO_PENDING_OTP"
        }
    }

    public var message: String {
        switch self {
        case .unknown(let detail), .serviceError(let detail), .invalidInput(let detail):
            detail
        case .invalidEmail:
            "Invalid email address"
        case .noPendingOTP:
            "No OTP email has been sent. Call sendEmailOtp first."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .invalidEmail:
            "Provide a valid email address in the correct format."
        case .noPendingOTP:
            "Call sendEmailOTP(to:) before attempting to verify an OTP."
        default:
            nil
        }
    }
}

/// The authentication state of the current session.
public enum AuthenticationStatus: Sendable, Equatable {
    /// No session exists.
    case nonAuthenticated
    /// A stored refresh token is being exchanged for a JWT (transient state at startup).
    case authenticating
    /// The user has a valid JWT. The `secret` is an opaque refresh token managed by the SDK.
    case authenticated(email: String, jwt: String, secret: String)

    public var isAuthenticated: Bool {
        guard case .authenticated = self else {
            return false
        }
        return true
    }
}

/// Returned by OTP flow methods to indicate either session state or a pending email.
public enum OTPAuthenticationStatus: Sendable, Equatable {
    /// Wraps the underlying ``AuthenticationStatus``.
    case authenticationStatus(AuthenticationStatus)
    /// An OTP email has been sent; ``CrossmintAuthManager/confirmEmailOtp(email:code:)`` is now expected.
    case emailSent(email: String, emailId: String)

    var isAuthenticating: Bool {
        switch self {
        case .emailSent:
            true
        default:
            false
        }
    }

    public var isAuthenticated: Bool {
        jwt != nil
    }

    public var email: String? {
        guard case let .authenticationStatus(.authenticated(email, _, _)) = self else {
            return nil
        }
        return email
    }

    var jwt: String? {
        guard case let .authenticationStatus(.authenticated(_, jwt, _)) = self else {
            return nil
        }
        return jwt
    }
}
