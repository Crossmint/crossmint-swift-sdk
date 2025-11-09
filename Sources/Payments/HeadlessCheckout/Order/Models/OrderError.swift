import CrossmintService
import Http

public enum OrderError: Error, ServiceError {
    case orderNotCreated
    case networkError(String)
    case decodingError
    case serviceUnavailable

    public static func fromServiceError(_ error: CrossmintServiceError) -> OrderError {
        return switch error {
        case .unknown:
            .networkError("Unknown error")
        case .invalidData(let message):
            .networkError("Invalid data: \(message)")
        case .invalidApiKey(let message):
            .networkError("Invalid API key: \(message)")
        case .invalidURL:
            .networkError("Invalid URL.")
        case .timeout:
            .networkError("Timeout")
        }
    }

    public static func fromNetworkError(_ error: NetworkError) -> OrderError {
        .networkError(error.localizedDescription)
    }

    public var errorMessage: String {
        switch self {
        case .orderNotCreated:
            return "Order has not been created yet"
        case .networkError(let message):
            return message
        case .decodingError:
            return "Failed to decode response"
        case .serviceUnavailable:
            return
                "Order service is unavailable. Make sure CrossmintService is properly initialized."
        }
    }
}
