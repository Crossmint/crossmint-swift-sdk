//
//  BalanceEndpoints.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 21/05/26.
//

import CrossmintCommonTypes
import Foundation
import Http

extension Endpoint {
    static func walletBalances(
        walletLocator: String,
        headers: [String: String] = [:],
        queryItems: [URLQueryItem]
    ) -> Endpoint {
        Endpoint(
            path: "/2025-06-09/wallets/\(walletLocator)/balances",
            method: .get,
            headers: headers,
            queryItems: queryItems
        )
    }
}
