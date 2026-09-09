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
    /// The recovery signer list was rejected. `code` is one of the stable codes below
    /// so callers can branch on it; `message` is the explanation that came with it.
    case recoveryConfigRejected(code: String, message: String)

    /// The list has more recovery signers than the chain allows.
    public static let SIGNER_LIMIT_EXCEEDED = "SIGNER_LIMIT_EXCEEDED"
    /// The same signer appears more than once in the list.
    public static let RECOVERY_DUPLICATE_SIGNER = "RECOVERY_DUPLICATE_SIGNER"
    /// A recovery signer is also registered as a delegated signer.
    public static let RECOVERY_SIGNER_CONFLICT = "RECOVERY_SIGNER_CONFLICT"
    /// The wallet has several recovery signers, so the operation must name the one that authorizes it.
    public static let SIGNER_REQUIRED = "SIGNER_REQUIRED"
    /// The chain accepts a single recovery signer only.
    public static let RECOVERY_NOT_SUPPORTED_ON_CHAIN = "RECOVERY_NOT_SUPPORTED_ON_CHAIN"
    /// The API version in use predates recovery signer lists.
    public static let NOT_SUPPORTED_ON_API_VERSION = "NOT_SUPPORTED_ON_API_VERSION"
    /// The request named both `adminSigner` and `recovery`. The SDK never sends both, so this
    /// points at a backend change.
    public static let RECOVERY_ADMIN_SIGNER_CONFLICT = "RECOVERY_ADMIN_SIGNER_CONFLICT"

    static let recoveryConfigCodes: Set<String> = [
        SIGNER_LIMIT_EXCEEDED,
        RECOVERY_DUPLICATE_SIGNER,
        RECOVERY_SIGNER_CONFLICT,
        SIGNER_REQUIRED,
        RECOVERY_NOT_SUPPORTED_ON_CHAIN,
        NOT_SUPPORTED_ON_API_VERSION,
        RECOVERY_ADMIN_SIGNER_CONFLICT
    ]

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
        case .walletInvalidSignerProvided: "WALLET_INVALID_SIGNER"
        case .transactionNotFound: "TRANSACTION_NOT_FOUND"
        case .invalidChain: "INVALID_CHAIN"
        case .invalidToken: "INVALID_TOKEN"
        case .signerNotRegistered: "SIGNER_NOT_REGISTERED"
        case .deviceSignerNotSupported: "DEVICE_SIGNER_NOT_SUPPORTED"
        case .recoveryConfigRejected(let code, _): code
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
        case .deviceSignerNotSupported(let message), .recoveryConfigRejected(_, let message):
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
        case .deviceSignerNotSupported:
            "Use the recovery signer or another registered signer for this wallet."
        case .recoveryConfigRejected(let code, _):
            Self.recoverySuggestion(forRecoveryCode: code)
        default:
            nil
        }
    }

    public var underlyingError: Swift.Error? {
        guard case .serviceError(let error) = self else { return nil }
        return error
    }
}

extension WalletError {
    static func defaultMessage(forRecoveryCode code: String) -> String {
        switch code {
        case SIGNER_LIMIT_EXCEEDED:
            "The wallet exceeds the maximum number of recovery signers"
        case RECOVERY_DUPLICATE_SIGNER:
            "The recovery list contains the same signer more than once"
        case RECOVERY_SIGNER_CONFLICT:
            "A recovery signer cannot also be registered as an operational signer"
        case SIGNER_REQUIRED:
            "This wallet has multiple recovery signers, so the signer to authorize with must be specified explicitly"
        case RECOVERY_NOT_SUPPORTED_ON_CHAIN:
            "Multiple recovery signers are not supported on this chain yet"
        case NOT_SUPPORTED_ON_API_VERSION:
            "Multiple recovery signers are not supported on this API version"
        case RECOVERY_ADMIN_SIGNER_CONFLICT:
            "Only one of `adminSigner` and `recovery` can be provided"
        default:
            "The recovery signer configuration was rejected"
        }
    }

    private static func recoverySuggestion(forRecoveryCode code: String) -> String? {
        switch code {
        case SIGNER_LIMIT_EXCEEDED:
            "Pass fewer recovery signers."
        case RECOVERY_DUPLICATE_SIGNER:
            "Remove the duplicated signer from the recovery list."
        case RECOVERY_SIGNER_CONFLICT:
            "Use a signer that is not already registered as a delegated signer."
        case SIGNER_REQUIRED:
            "Call useSigner to select which recovery signer authorizes this operation."
        case RECOVERY_NOT_SUPPORTED_ON_CHAIN:
            "Pass a single recovery signer on this chain."
        default:
            nil
        }
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
