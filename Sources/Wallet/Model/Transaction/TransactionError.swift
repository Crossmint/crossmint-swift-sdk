import CrossmintService
import Http

public enum TransactionError: ServiceError {
    case serviceError(CrossmintServiceError)
    case transactionNotFound
    case transactionCreationFailed
    case userCancelled
    case invalidApprovals(expected: Int, actual: Int)
    case transactionCreationFailedNoSigner
    case transactionSigningFailedNoSigner
    case transactionSigningFailedNoMessage
    case transactionSigningFailedInvalidKey
    case transactionSigningFailed
    case transactionGeneric(String)

    public var errorMessage: String {
        switch self {
        case .serviceError(let error):
            return error.errorMessage
        case .invalidApprovals(let expected, let actual):
            return "Invalid approvals. Expected: \(expected), Actual: \(actual)"
        case .transactionNotFound:
            return "Transaction not found"
        case .transactionCreationFailed:
            return "Transaction creation failed"
        case .transactionCreationFailedNoSigner:
            return "Transaction creation failed: no signer"
        case .transactionGeneric(let error):
            return error
        case .transactionSigningFailed:
            return "Transaction signing failed"
        case .transactionSigningFailedNoSigner:
            return "Transaction signing failed: no signer"
        case .transactionSigningFailedNoMessage:
            return "Transaction signing failed: no message"
        case .transactionSigningFailedInvalidKey:
            return "Transaction signing failed: invalid key"
        case .userCancelled:
            return "The user cancelled the signing"
        }
    }

    public static func fromServiceError(_ error: CrossmintServiceError) -> TransactionError {
        .serviceError(error)
    }

    public static func fromNetworkError(_ error: NetworkError) -> TransactionError {
        let message = error.serviceErrorMessage ?? error.localizedDescription
        return switch error {
        case .forbidden:
                .serviceError(.invalidApiKey(message))
        case .timeout:
                .serviceError(.timeout)
        default:
                .transactionGeneric(message)
        }
    }
}
