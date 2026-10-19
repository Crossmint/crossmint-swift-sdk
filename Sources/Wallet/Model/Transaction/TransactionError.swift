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
    /// This device approved as each quorum member that it has a signer for.
    /// Other members must still approve the transaction.
    case awaitingQuorumApproval(transactionId: String)
    /// The transaction expired before it got all the approvals. Create a new transaction.
    case transactionExpired(String)
    /// The signer is a member of a quorum. A member can approve a transaction.
    /// A member cannot create a transaction.
    case signerIsQuorumMember(String)

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
        case .awaitingQuorumApproval: "AWAITING_QUORUM_APPROVAL"
        case .transactionExpired: "TRANSACTION_EXPIRED"
        case .signerIsQuorumMember: "SIGNER_IS_QUORUM_MEMBER"
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
        case .transactionGeneric(let detail), .transactionExpired(let detail), .signerIsQuorumMember(let detail):
            detail
        case .awaitingQuorumApproval(let transactionId):
            "Other quorum members must approve transaction \(transactionId)"
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
        case .transactionCreationFailedNoSigner:
            "Call useSigner(_:) before you send a transaction. "
                + "For a passkey, you can also set passkeyHost in WalletOptions when you get the wallet."
        case .transactionSigningFailedNoSigner:
            "Ensure a signer is configured before initiating a transaction."
        case .transactionSigningFailedInvalidKey:
            "Verify that the signing key is valid and has not been revoked."
        case .awaitingQuorumApproval:
            "Give the transaction ID to the other quorum members. Each member calls approve(transactionId:)."
        case .transactionExpired:
            "Send the transaction again."
        case .signerIsQuorumMember:
            "Name the quorum as the signer."
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
