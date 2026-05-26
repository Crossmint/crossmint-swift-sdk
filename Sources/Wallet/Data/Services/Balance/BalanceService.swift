//
//  BalanceService.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 21/05/26.
//

import CrossmintCommonTypes

public protocol BalanceService: Sendable {
    func getBalance(
        _ params: GetBalanceQueryParams
    ) async throws(WalletError) -> Balances
}
