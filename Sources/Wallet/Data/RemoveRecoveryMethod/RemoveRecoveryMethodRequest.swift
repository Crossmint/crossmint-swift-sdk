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
        approver: SignerLocator,
        chain: String?
    ) -> Endpoint {
        var queryItems = [URLQueryItem(name: "approver", value: approver.value)]
        if let chain {
            queryItems.append(URLQueryItem(name: "chain", value: chain))
        }
        return Endpoint(
            path: "/2025-06-09/wallets/me:\(chainType.rawValue)/recovery-methods/\(encodedLocator)",
            method: .delete,
            queryItems: queryItems
        )
    }
}
