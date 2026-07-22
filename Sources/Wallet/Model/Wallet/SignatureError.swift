import CrossmintService
import Http

public enum SignatureError: CrossmintError {
    case creationFailed
    case approvalFailed
    /// The wallet failed to produce the signature. `underlyingError` holds the original error.
    case signingFailed(underlyingError: Error)
    case userCancelled
    case serviceError(CrossmintServiceError)
    case networkError
    case unknown
    case decodingError

    public var code: String {
        switch self {
        case .creationFailed: "SIGNATURE_CREATION_FAILED"
        case .approvalFailed: "SIGNATURE_APPROVAL_FAILED"
        case .signingFailed: "SIGNATURE_SIGNING_FAILED"
        case .userCancelled: "USER_CANCELLED"
        case .serviceError: "SERVICE_ERROR"
        case .networkError: "NETWORK_ERROR"
        case .unknown: "SIGNATURE_UNKNOWN"
        case .decodingError: "SIGNATURE_DECODING_ERROR"
        }
    }

    public var message: String {
        switch self {
        case .serviceError(let error):
            error.message
        case .approvalFailed:
            "There was an error while approving the message"
        case .signingFailed:
            "There was an error while producing the signature"
        case .userCancelled:
            "User cancelled this action"
        case .creationFailed:
            "The creation failed"
        case .networkError:
            "There was a backend error."
        case .unknown:
            "Unknown signature type"
        case .decodingError:
            "Failed to decode signature response"
        }
    }

    public var underlyingError: Swift.Error? {
        switch self {
        case .serviceError(let error): error
        case .signingFailed(let error): error
        default: nil
        }
    }
}

extension SignatureError: CrossmintMappableError {
    public static func fromServiceError(_ error: CrossmintServiceError) -> SignatureError {
        .serviceError(error)
    }

    public static func fromNetworkError(_ error: NetworkError) -> SignatureError {
        .networkError
    }
}
