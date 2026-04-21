//
//  SupportedChain.swift
//  SmartWalletsDemo
//

import CrossmintClient
import SwiftUI

enum SupportedChain: Equatable, Identifiable {
    case evm
    case solana
    case stellar

    var id: Self { self }

    @ViewBuilder
    var icon: some View {
        switch self {
        case .evm:
            Image("eth")
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
        case .solana:
            Image("solana")
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
        case .stellar:
            Image("stellar")
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
        }
    }

    var name: String {
        switch self {
        case .evm: "EVM"
        case .solana: "Solana"
        case .stellar: "Stellar"
        }
    }

    var chainDisplayName: String {
        switch self {
        case .evm: "Base Sepolia"
        case .solana: "Solana"
        case .stellar: "Stellar"
        }
    }

    var balanceCurrencies: [CryptoCurrency] {
        switch self {
        case .evm: [.eth, .usdc, .usdxm]
        case .solana: [.sol, .usdc, .usdxm]
        case .stellar: [.xlm, .usdxm]
        }
    }

    var transferTokens: [(name: String, locator: String)] {
        switch self {
        case .evm:
            [("USDXM", "base-sepolia:usdxm"), ("USDC", "base-sepolia:usdc"), ("ETH", "base-sepolia:eth")]
        case .solana:
            [("USDXM", "solana:usdxm"), ("USDC", "solana:usdc"), ("SOL", "solana:sol")]
        case .stellar:
            [("USDXM", "stellar:usdxm"), ("XLM", "stellar:xlm")]
        }
    }

    var fundToken: CryptoCurrency { .usdxm }

    var supportsMessageSigning: Bool {
        self == .evm
    }
}
