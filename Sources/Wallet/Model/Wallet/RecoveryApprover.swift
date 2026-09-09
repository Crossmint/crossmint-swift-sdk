//
//  RecoveryApprover.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 09/09/26.
//

struct RecoveryApprover {
    let locator: String
    let signer: any Signer
    let named: Bool

    var requestLocator: String? {
        named ? locator : nil
    }
}
