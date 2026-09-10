import CrossmintCommonTypes
import CrossmintService
import Http

public enum WalletError: CrossmintError {
    case serviceError(CrossmintServiceError)
    case walletInvalidType(String)
    case walletNotFound
    case walletCreationFailed(String)
    case walletCreationCancelled
    case walletGeneric(String)
    case walletInvalidCredentials
    case walletLocatorError(String)
    case signerLocatorError(String)
    case walletInvalidSignerProvided
    case transactionNotFound
    case invalidChain(chain: Chain)
    case invalidToken(token: CryptoCurrency)
    case signerNotRegistered(String)
    /// The wallet's underlying provider does not support device signers,
    /// surfaced from the backend's stable `DEVICE_SIGNER_NOT_SUPPORTED`
    /// error code. ``Wallet/recover()`` catches it and falls back to the
    /// recovery signer.
    case deviceSignerNotSupported(String)

    public var code: String {
        switch self {
        case .serviceError: "SERVICE_ERROR"
        case .walletInvalidType: "WALLET_INVALID_TYPE"
        case .walletNotFound: "WALLET_NOT_FOUND"
        case .walletCreationFailed: "WALLET_CREATION_FAILED"
        case .walletCreationCancelled: "WALLET_CREATION_CANCELLED"
        case .walletGeneric: "WALLET_ERROR"
        case .walletInvalidCredentials: "WALLET_INVALID_CREDENTIALS"
        case .walletLocatorError: "WALLET_LOCATOR_ERROR"
        case .signerLocatorError: "SIGNER_LOCATOR_ERROR"
        case .walletInvalidSignerProvided: "WALLET_INVALID_SIGNER"
        case .transactionNotFound: "TRANSACTION_NOT_FOUND"
        case .invalidChain: "INVALID_CHAIN"
        case .invalidToken: "INVALID_TOKEN"
        case .signerNotRegistered: "SIGNER_NOT_REGISTERED"
        case .deviceSignerNotSupported: "DEVICE_SIGNER_NOT_SUPPORTED"
        }
    }

    public var message: String {
        switch self {
        case .serviceError(let error):
            error.message
        case .walletInvalidType(let detail), .walletGeneric(let detail), .walletCreationFailed(let detail):
            detail
        case .walletNotFound:
            "Wallet not found"
        case .walletInvalidCredentials:
            "The credentials provided are invalid for this wallet."
        case .walletLocatorError(let locator):
            "Invalid wallet locator: \(locator)"
        case .signerLocatorError(let locator):
            "Invalid signer locator: \(locator)"
        case .transactionNotFound:
            "Transaction not found"
        case .walletInvalidSignerProvided:
            "The provided admin signer and the received one do not match"
        case .walletCreationCancelled:
            "Creation cancelled."
        case .invalidChain(let chain):
            "Invalid chain: \(chain.name)"
        case .invalidToken(let token):
            "Invalid token: \(token.name)"
        case .signerNotRegistered(let locator):
            "Signer \"\(locator)\" is not registered on this wallet. Call addSigner first."
        case .deviceSignerNotSupported(let message):
            message
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .walletNotFound:
            "Create a wallet using wallets.getOrCreate(chain:signer:)"
        case .walletInvalidCredentials:
            "Verify your signer configuration matches the wallet's registered signer."
        case .signerNotRegistered:
            "Call addSigner before attempting operations that require this signer."
        case .invalidChain:
            "Check the list of supported chains for this environment."
        case .walletLocatorError:
            "Ensure the wallet locator is in the correct format."
        case .signerLocatorError:
            "Use the correct signer locator format, for example \"email:user@example.com\"."
        case .deviceSignerNotSupported:
            "Use the recovery signer or another registered signer for this wallet."
        default:
            nil
        }
    }

    public var underlyingError: Swift.Error? {
        guard case .serviceError(let error) = self else { return nil }
        return error
    }
}

extension WalletError: CrossmintMappableError {
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
