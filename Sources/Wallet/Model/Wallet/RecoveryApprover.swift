//
//  RecoveryApprover.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 17/09/26.
//

struct RecoveryApprover {
    let signer: any Signer
    let locator: SignerLocator?
    var approvingMembers: [SignerLocator]?

    var approval: SignerChangeApproval? {
        locator.map { SignerChangeApproval(approver: $0, approvingMembers: approvingMembers) }
    }

    var isQuorum: Bool {
        guard case .quorum = locator else { return false }
        return true
    }
}
