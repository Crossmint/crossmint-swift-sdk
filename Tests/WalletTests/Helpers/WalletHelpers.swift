//
//  WalletHelpers.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 06/10/26.
//

import Foundation
import TestsUtils

@testable import Wallet

func makeWallet(fixture: String, walletService: MockSmartWalletService) throws -> Wallet {
    let baseModel: WalletApiModel = try GetFromFile.getModelFrom(fileName: fixture, bundle: Bundle.module)
    switch baseModel.chainType {
    case .solana:
        return try SolanaWallet(
            smartWalletService: walletService,
            signer: nil,
            baseModel: baseModel,
            solanaChain: .solana
        )
    case .stellar:
        return try StellarWallet(
            smartWalletService: walletService,
            signer: nil,
            baseModel: baseModel,
            stellarChain: .stellar
        )
    default:
        return try EVMWallet(
            smartWalletService: walletService,
            signer: nil,
            baseModel: baseModel,
            evmChain: .baseSepolia
        )
    }
}
