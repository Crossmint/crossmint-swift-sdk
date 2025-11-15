import CrossmintService
import Http

public enum SignatureError: ServiceError {
    case creationFailed
    case approvalFailed
    case userCancelled
    case serviceError(CrossmintServiceError)
    case networkError
    case unknown
    case decodingError

    public var errorMessage: String {
        switch self {
        case let .serviceError(error):
            return error.errorMessage
        case .approvalFailed:
            return "There was an error while approving the message"
        case .userCancelled:
            return "User cancelled this action"
        case .creationFailed:
            return "The creation failed"
        case .networkError:
            return "There was a backend error."
        case .unknown:
            return "Unknown signature type"
        case .decodingError:
            return "Failed to decode signature response"
        }
    }

    public static func fromServiceError(_ error: CrossmintServiceError) -> SignatureError {
        .serviceError(error)
    }

    public static func fromNetworkError(_ error: NetworkError) -> SignatureError {
        .networkError
    }
}
