import CrossmintCommonTypes
import CrossmintService
import Http

public enum WalletError: ServiceError {
    case serviceError(CrossmintServiceError)
    case walletInvalidType(String)
    case walletNotFound
    case walletCreationFailed(String)
    case walletCreationCancelled
    case walletGeneric(String)
    case walletInvalidCredentials
    case walletLocatorError(String)
    case walletInvalidSignerProvided
    case transactionNotFound
    case invalidChain(chain: Chain)
    case invalidToken(token: CryptoCurrency)

    public var errorMessage: String {
        switch self {
        case let .serviceError(error):
            return error.errorMessage
        case .walletInvalidType(let message), .walletGeneric(let message),
            .walletCreationFailed(let message):
            return message
        case .walletNotFound:
            return "Wallet not found"
        case .walletInvalidCredentials:
            return "The credentials provided are invalid for this wallet."
        case .walletLocatorError(let locator):
            return "Invalid wallet locator: \(locator)"
        case .transactionNotFound:
            return "Transaction not found"
        case .walletInvalidSignerProvided:
            return "The provided admin signer and the received one do not match"
        case .walletCreationCancelled:
            return "Creation cancelled."
        case .invalidChain(let chain):
            return "Invalid chain: \(chain.name)"
        case .invalidToken(let token):
            return "Invalid token: \(token.name)"
        }
    }

    public static func fromServiceError(_ error: CrossmintServiceError) -> WalletError {
        .serviceError(error)
    }

    public static func fromNetworkError(_ error: NetworkError) -> WalletError {
        let message = error.serviceErrorMessage ?? error.localizedDescription
        return switch error {
        case .notFound:
            .walletNotFound
        case .forbidden:
            .serviceError(.invalidApiKey(message))
        default:
            .walletGeneric(message)
        }
    }
}
