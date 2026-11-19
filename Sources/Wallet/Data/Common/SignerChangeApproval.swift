//
//  SignerChangeApproval.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 12/11/26.
//

import CrossmintCommonTypes

/// The signer that approves a signer change, and the quorum members that approve for a Solana quorum.
public struct SignerChangeApproval: Sendable, Equatable {
    /// The signer that approves the change. This can be a quorum.
    public let approver: SignerLocator
    /// The quorum members that approve, when the approver is a quorum on a Solana wallet.
    public let approvingMembers: [SignerLocator]?

    /// Makes an approval for a signer change.
    public init(approver: SignerLocator, approvingMembers: [SignerLocator]? = nil) {
        self.approver = approver
        self.approvingMembers = approvingMembers
    }
}
