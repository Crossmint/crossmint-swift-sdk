import CrossmintService
import Http

public enum TransactionError: CrossmintError {
    case serviceError(CrossmintServiceError)
    case transactionNotFound
    case transactionCreationFailed
    case userCancelled
    case invalidApprovals(expected: Int, actual: Int)
    case transactionCreationFailedNoSigner
    case transactionSigningFailedNoSigner
    case transactionSigningFailedNoMessage
    case transactionSigningFailedInvalidKey
    case transactionSigningFailed(Error)
    case transactionGeneric(String)

    public var code: String {
        switch self {
        case .serviceError: "SERVICE_ERROR"
        case .transactionNotFound: "TRANSACTION_NOT_FOUND"
        case .transactionCreationFailed: "TRANSACTION_CREATION_FAILED"
        case .userCancelled: "USER_CANCELLED"
        case .invalidApprovals: "INVALID_APPROVALS"
        case .transactionCreationFailedNoSigner: "TRANSACTION_CREATION_FAILED_NO_SIGNER"
        case .transactionSigningFailedNoSigner: "TRANSACTION_SIGNING_FAILED_NO_SIGNER"
        case .transactionSigningFailedNoMessage: "TRANSACTION_SIGNING_FAILED_NO_MESSAGE"
        case .transactionSigningFailedInvalidKey: "TRANSACTION_SIGNING_FAILED_INVALID_KEY"
        case .transactionSigningFailed: "TRANSACTION_SIGNING_FAILED"
        case .transactionGeneric: "TRANSACTION_ERROR"
        }
    }

    public var message: String {
        switch self {
        case .serviceError(let error):
            error.message
        case .invalidApprovals(let expected, let actual):
            "Invalid approvals. Expected: \(expected), Actual: \(actual)"
        case .transactionNotFound:
            "Transaction not found"
        case .transactionCreationFailed:
            "Transaction creation failed"
        case .transactionCreationFailedNoSigner:
            "Transaction creation failed: no signer"
        case .transactionGeneric(let detail):
            detail
        case .transactionSigningFailed:
            "Transaction signing failed"
        case .transactionSigningFailedNoSigner:
            "Transaction signing failed: no signer"
        case .transactionSigningFailedNoMessage:
            "Transaction signing failed: no message"
        case .transactionSigningFailedInvalidKey:
            "Transaction signing failed: invalid key"
        case .userCancelled:
            "The user cancelled the signing"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .transactionCreationFailedNoSigner, .transactionSigningFailedNoSigner:
            "Ensure a signer is configured before initiating a transaction."
        case .transactionSigningFailedInvalidKey:
            "Verify that the signing key is valid and has not been revoked."
        default:
            nil
        }
    }

    public var underlyingError: Swift.Error? {
        switch self {
        case .serviceError(let error): error
        case .transactionSigningFailed(let error): error
        default: nil
        }
    }
}

extension TransactionError: CrossmintMappableError {
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
