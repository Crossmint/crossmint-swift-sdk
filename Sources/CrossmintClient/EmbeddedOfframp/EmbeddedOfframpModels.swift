import CrossmintService

/// The `sessionId` and `clientSecret` that Create Offramp Session returns. Create the session on your server.
public struct EmbeddedOfframpCredentials: Codable, Sendable {
    public let sessionId: String
    public let clientSecret: String

    public init(sessionId: String, clientSecret: String) {
        self.sessionId = sessionId
        self.clientSecret = clientSecret
    }
}

extension EmbeddedOfframpCredentials: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String { "EmbeddedOfframpCredentials(sessionId: \(sessionId))" }
    public var debugDescription: String { description }
}

/// A language of the offramp screens. The offramp supports only these languages.
public enum OfframpLocale: String, Sendable, CaseIterable {
    case enUS = "en-US"
    case esES = "es-ES"
    case frFR = "fr-FR"
    case itIT = "it-IT"
    case koKR = "ko-KR"
    case ptPT = "pt-PT"
    case jaJP = "ja-JP"
    case zhCN = "zh-CN"
    case zhTW = "zh-TW"
    case deDE = "de-DE"
    case ruRU = "ru-RU"
    case trTR = "tr-TR"
    case ukUA = "uk-UA"
    case thTH = "th-TH"
    case viVN = "vi-VN"
}

/// The step of the offramp flow. `unknown` is a step this SDK version does not know.
public enum OfframpStatus: String, Decodable, Sendable {
    case loading
    case enteringAmount = "entering-amount"
    case selectingBank = "selecting-bank"
    case addingBank = "adding-bank"
    case verifyingIdentity = "verifying-identity"
    case identityInReview = "identity-in-review"
    case verifyingWallet = "verifying-wallet"
    case reviewing
    case awaitingSignature = "awaiting-signature"
    case confirmingDeposit = "confirming-deposit"
    case completed
    case payoutCompleted = "payout-completed"
    case payoutFailed = "payout-failed"
    case failed
    case unknown

    public init(from decoder: Decoder) throws {
        self = Self(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
    }
}

/// A move of the offramp flow to another step.
public struct OfframpStatusChange: Decodable, Sendable {
    public let status: OfframpStatus
    /// The order of the withdrawal, once there is one. It can change during one withdrawal, so keep the latest.
    public let orderId: String?
}

/// A confirmed deposit. The bank payout can still be pending.
public struct OfframpCompletion: Decodable, Sendable {
    public let orderId: String
    public let txId: String
}

/// An error of the offramp flow. When `retriable` is `false`, the session cannot continue: remove the view.
public struct OfframpError: Decodable, CrossmintError {
    /// Why the error happened. `unknown` is a reason this SDK version does not know.
    public enum Reason: String, Decodable, Sendable {
        case invalidCredentials = "invalid-credentials"
        case invalidConfiguration = "invalid-configuration"
        case sessionSpent = "session-spent"
        case identityVerificationRequired = "identity-verification-required"
        case identityVerificationFailed = "identity-verification-failed"
        case walletOwnershipRequired = "wallet-ownership-required"
        case bankNotSupported = "bank-not-supported"
        case bankNotVerified = "bank-not-verified"
        case bankHolderMismatch = "bank-holder-mismatch"
        case amountTooLow = "amount-too-low"
        case amountTooHigh = "amount-too-high"
        case exactPayoutUnsupported = "exact-payout-unsupported"
        case insufficientFunds = "insufficient-funds"
        case walletRejected = "wallet-rejected"
        case payoutFailed = "payout-failed"
        case providerError = "provider-error"
        case unknown

        public init(from decoder: Decoder) throws {
            self = Self(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
        }
    }

    public let reason: Reason
    public let retriable: Bool
    /// The text is for logs, not for the user.
    public let message: String
    public var code: String { reason.rawValue.replacingOccurrences(of: "-", with: "_").uppercased() }
}
