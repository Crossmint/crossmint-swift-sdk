import Foundation
import Http

public protocol CrossmintError: Swift.Error, Sendable, CustomStringConvertible {
    var code: String { get }
    var message: String { get }
    var recoverySuggestion: String? { get }
    var underlyingError: Swift.Error? { get }
}

extension CrossmintError {
    public var description: String {
        var result = "[\(code)] \(message)"
        if let suggestion = recoverySuggestion {
            result += "\nRecovery: \(suggestion)"
        }
        return result
    }

    public var recoverySuggestion: String? { nil }
    public var underlyingError: Swift.Error? { nil }
}

/// SDK-internal protocol. Conformance is managed by the SDK — do not adopt this in app code.
public protocol CrossmintMappableError: CrossmintError {
    static func fromServiceError(_ error: CrossmintServiceError) -> Self
    static func fromNetworkError(_ error: NetworkError) -> Self
}
