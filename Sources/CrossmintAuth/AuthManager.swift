import CrossmintService
import Foundation
import Logger

public protocol AuthManager: Sendable {
    var jwt: String? { get async }

    func setJWT(_ jwt: String) async
}

public enum AuthManagerError: CrossmintError, Equatable {
    case unknown(String)
    case serviceError(String)
    case invalidInput(String)
    case invalidEmail
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

public enum AuthenticationStatus: Sendable, Equatable {
    case nonAuthenticated
    case authenticating
    case authenticated(email: String, jwt: String, secret: String)

    public var isAuthenticated: Bool {
        guard case .authenticated = self else {
            return false
        }
        return true
    }
}

public enum OTPAuthenticationStatus: Sendable, Equatable {
    case authenticationStatus(AuthenticationStatus)
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
