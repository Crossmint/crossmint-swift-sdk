//
//  RecoveryApprover.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 17/09/26.
//

struct RecoveryApprover {
    let signer: any Signer
    let locator: SignerLocator?

    var isQuorum: Bool {
        guard case .quorum = locator else { return false }
        return true
    }
}
