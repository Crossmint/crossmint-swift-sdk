//
//  SignerStatus.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 7/14/26.
//

/// The registration state of a signer as it moves through approval.
public enum SignerStatus: String, Sendable {
    /// Submitted but not yet routed for approval.
    case pending
    /// Waiting for one or more approvals before it becomes active.
    case awaitingApproval = "awaiting-approval"
    /// Registered and usable.
    case active
    /// Rejected or reverted.
    case failed
    /// The backend returned a status this SDK doesn't recognize, or omitted it.
    case unknown

    /// Parses a raw status string, treating the legacy `"success"` response as ``active``
    /// and falling back to ``unknown`` for anything `nil` or unrecognized.
    public static func from(_ rawValue: String?) -> SignerStatus {
        if rawValue == "success" { return .active }
        guard let rawValue else { return .unknown }
        return SignerStatus(rawValue: rawValue) ?? .unknown
    }
}

extension SignerStatus: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = .from(try? container.decode(String.self))
    }
}
