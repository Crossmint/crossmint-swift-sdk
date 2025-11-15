import CrossmintService
import Http

public enum CheckoutComError: Error, ServiceError {
    case networkError(String)
    case invalidOrderState(String)

    public static func fromServiceError(_ error: CrossmintServiceError) -> CheckoutComError {
        return switch error {
        case .unknown:
            .networkError("Unknown error")
        case .invalidData(let message):
            .networkError("Invalid data: \(message)")
        case .invalidApiKey(let message):
            .networkError("Invalid API key: \(message)")
        case .invalidURL:
            .networkError("Invalid URL")
        case .timeout:
            .networkError("Timeout")
        }
    }

    public static func fromNetworkError(_ error: NetworkError) -> CheckoutComError {
        .networkError(error.localizedDescription)
    }

    public var errorMessage: String {
        switch self {
        case .networkError(let message):
            return message
        case .invalidOrderState(let message):
            return message
        }
    }
}
