//
//  PendingDeviceKey.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 24/10/26.
//

import DeviceSigner

struct PendingDeviceKey: Sendable {
    let transactionId: String
    let publicKeyBase64: String
    let storage: any DeviceSignerKeyStorage
    var replacedSigner: SignerLocator?
}
