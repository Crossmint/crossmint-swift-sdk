//
//  RemoveRecoveryMethodRequest.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 25/09/26.
//

import CrossmintCommonTypes
import Foundation
import Http

extension Endpoint {
    static func removeRecoveryMethod(
        chainType: ChainType,
        encodedLocator: String,
        approver: SignerLocator
    ) -> Endpoint {
        Endpoint(
            path: "/2025-06-09/wallets/me:\(chainType.rawValue)/recovery-methods/\(encodedLocator)",
            method: .delete,
            queryItems: [URLQueryItem(name: "approver", value: approver.value)]
        )
    }
}
