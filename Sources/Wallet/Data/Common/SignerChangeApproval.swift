//
//  SignerChangeApproval.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 12/11/26.
//

import CrossmintCommonTypes

public struct SignerChangeApproval: Sendable, Equatable {
    public let approver: SignerLocator
    public let approvingMembers: [SignerLocator]?

    public init(approver: SignerLocator, approvingMembers: [SignerLocator]? = nil) {
        self.approver = approver
        self.approvingMembers = approvingMembers
    }
}
