import CrossmintService
import Foundation
import Utils

public struct EmbeddedOfframpCredentials: Codable, Sendable {
    public let sessionId: String
    public let clientSecret: String

    public init(sessionId: String, clientSecret: String) {
        self.sessionId = sessionId
        self.clientSecret = clientSecret
    }
}

public struct EmbeddedOfframpConfiguration: Sendable {
    let url: URL

    /// Credentials must be minted by your backend. Never pass a server API key to the app.
    /// Appearance accepts the same Encodable object shape as embedded checkout (fonts, variables, rules).
    public init(
        apiKey: String,
        credentials: EmbeddedOfframpCredentials,
        locale: String? = nil,
        appearance: (any Encodable)? = nil
    ) throws {
        let key = try ApiKey(key: apiKey)
        guard key.type == .client, !credentials.sessionId.isEmpty, !credentials.clientSecret.isEmpty else {
            throw OfframpError(reason: "invalid-configuration", retriable: false,
                               message: "A client API key and nonempty session credentials are required")
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "\(key.apiEnvironmentPathComponent)crossmint.com"
        components.path = "/sdk/unstable/embedded-offramp"
        let encoder = JSONEncoder()
        var query = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "credentials", value: String(data: try encoder.encode(credentials), encoding: .utf8)),
            URLQueryItem(name: "sdkMetadata", value: String(
                data: try encoder.encode(["name": "crossmint-swift-sdk", "version": SDKVersion.version]),
                encoding: .utf8
            ))
        ]
        if let locale {
            query.append(URLQueryItem(name: "locale", value: locale))
        }
        if let appearance {
            query.append(URLQueryItem(name: "appearance",
                                      value: String(data: try encoder.encode(appearance), encoding: .utf8)))
        }
        components.queryItems = query
        guard let url = components.url else {
            throw OfframpError(reason: "invalid-configuration", retriable: false, message: "Invalid offramp URL")
        }
        self.url = url
    }

    func trusts(_ candidate: URL?) -> Bool {
        guard let candidate else { return false }
        return candidate.scheme == "https" && candidate.host == url.host
            && (candidate.port == nil || candidate.port == 443)
            && candidate.user == nil && candidate.password == nil && candidate.path == url.path
    }
}

public struct OfframpTransaction: Decodable, Hashable, Sendable {
    public let serializedTransaction: String
    public let chain: String
    public let payerAddress: String
}

/// Throw only when the wallet definitively refused before broadcasting. Other failures retain the sign intent.
public struct OfframpSignatureRejected: CrossmintError {
    public let code = "OFFRAMP_SIGNATURE_REJECTED"
    public let message: String

    public init(message: String = "The wallet rejected the transaction") {
        self.message = message
    }
}

public struct OfframpError: Decodable, CrossmintError {
    public let reason: String
    public let retriable: Bool
    public let message: String
    public var code: String { reason.replacingOccurrences(of: "-", with: "_").uppercased() }
}

public struct OfframpStatusChange: Decodable, Sendable {
    public let status: OfframpStatus
    public let orderId: String?
}

public enum OfframpStatus: String, Decodable, Sendable {
    case loading
    case enteringAmount = "entering-amount"
    case selectingBank = "selecting-bank"
    case addingBank = "adding-bank"
    case verifyingIdentity = "verifying-identity"
    case identityInReview = "identity-in-review"
    case reviewing
    case awaitingSignature = "awaiting-signature"
    case confirmingDeposit = "confirming-deposit"
    case completed
    case payoutCompleted = "payout-completed"
    case payoutFailed = "payout-failed"
    case failed
}

public struct OfframpCompletion: Decodable, Sendable {
    public let orderId: String
    public let txId: String
}

@MainActor
public struct EmbeddedOfframpCallbacks {
    public var onReady: () -> Void
    public var onStatusChange: (OfframpStatusChange) -> Void
    public var onComplete: (OfframpCompletion) -> Void
    public var onCancel: () -> Void
    public var onError: (OfframpError) -> Void
    public var onHeightChange: (Double) -> Void

    public init(
        onReady: @escaping () -> Void = {},
        onStatusChange: @escaping (OfframpStatusChange) -> Void = { _ in },
        onComplete: @escaping (OfframpCompletion) -> Void = { _ in },
        onCancel: @escaping () -> Void = {},
        onError: @escaping (OfframpError) -> Void = { _ in },
        onHeightChange: @escaping (Double) -> Void = { _ in }
    ) {
        self.onReady = onReady
        self.onStatusChange = onStatusChange
        self.onComplete = onComplete
        self.onCancel = onCancel
        self.onError = onError
        self.onHeightChange = onHeightChange
    }
}
