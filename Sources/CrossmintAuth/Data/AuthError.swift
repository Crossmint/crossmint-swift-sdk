import CrossmintService
import Http

public enum AuthError: CrossmintError {
    case serviceError(CrossmintServiceError)
    case signInRequired
    case generic(String)

    public var code: String {
        switch self {
        case .serviceError: "SERVICE_ERROR"
        case .signInRequired: "SIGN_IN_REQUIRED"
        case .generic: "AUTH_ERROR"
        }
    }

    public var message: String {
        switch self {
        case .serviceError(let error):
            error.message
        case .generic(let detail):
            detail
        case .signInRequired:
            "Sign in is required as the operation was unauthorized"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .signInRequired:
            "Call sendEmailOTP(to:) to begin authentication."
        default:
            nil
        }
    }

    public var underlyingError: Swift.Error? {
        guard case .serviceError(let error) = self else { return nil }
        return error
    }
}

extension AuthError: CrossmintMappableError {
    public static func fromServiceError(_ error: CrossmintServiceError) -> AuthError {
        .serviceError(error)
    }

    public static func fromNetworkError(_ error: NetworkError) -> AuthError {
        let message = error.serviceErrorMessage ?? error.localizedDescription
        return switch error {
        case .unauthorized:
            .signInRequired
        case .forbidden:
            .serviceError(.invalidApiKey(message))
        default:
            .generic(message)
        }
    }
}
