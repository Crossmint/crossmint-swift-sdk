//
//  NFTService.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 21/05/26.
//

import CrossmintCommonTypes

public protocol NFTService: Sendable {
    func getNFTs(
        _ params: GetNTFQueryParams
    ) async throws(WalletError) -> [NFT]
}
