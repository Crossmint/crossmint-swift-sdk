//
//  QuorumConfig.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 16/10/26.
//

import CrossmintCommonTypes

/// A recovery method that approves only when `threshold` of its `members` approve.
///
/// Stellar wallets only. Other chains reject a quorum with
/// ``WalletError/RecoveryConfigCode/quorumUnsupported``.
///
/// ## Example
/// ```swift
/// let quorum = QuorumConfig(
///     threshold: 2,
///     members: [
///         StellarSigners.email("alice@example.com").signer,
///         StellarSigners.email("bob@example.com").signer,
///         StellarSigners.phone("+14155552671").signer
///     ]
/// )
/// ```
public struct QuorumConfig: Sendable {
    public let threshold: Int
    /// The signers of the quorum. A quorum needs two to ten members.
    /// An API key signer or a device signer cannot be a member.
    public let members: [any Signer]

    public init(threshold: Int, members: [any Signer]) {
        self.threshold = threshold
        self.members = members
    }

    func input() async -> QuorumSignerInput {
        var memberData: [any AdminSignerData] = []
        for member in members {
            memberData.append(await member.adminSigner)
        }
        return QuorumSignerInput(threshold: threshold, members: memberData)
    }
}

struct QuorumSignerInput: AdminSignerData {
    let threshold: Int
    let members: [any AdminSignerData]

    var type: AdminSignerDataType { .quorum }
    var locatorId: String { "" }
}
