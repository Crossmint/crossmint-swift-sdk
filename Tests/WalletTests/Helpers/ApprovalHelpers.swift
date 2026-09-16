//
//  ApprovalHelpers.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 16/09/26.
//

@testable import Wallet

extension SignRequestApi.Approval {
    var keypair: (String, String)? {
        guard case let .keypair(signer, signature) = self else { return nil }
        return (signer, signature)
    }

    var device: (String, DeviceSignature)? {
        guard case let .device(signer, signature) = self else { return nil }
        return (signer, signature)
    }
}
