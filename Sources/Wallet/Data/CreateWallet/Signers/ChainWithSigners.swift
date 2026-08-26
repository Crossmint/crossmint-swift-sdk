//
//  ChainWithSigners.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 01/09/26.
//

import CrossmintCommonTypes

/// Protocol that associates a `SpecificChain` with its corresponding `SignerProvider`.
///
/// This protocol extends `SpecificChain` to add the signer provider association,
/// enabling generic wallet creation methods that work across all chains without
/// requiring separate method overloads per chain type.
public protocol ChainWithSigners: SpecificChain {
    associatedtype SpecificSigner: SignerProvider
    associatedtype WalletType: Wallet
}

// MARK: - Chain Conformances

extension EVMChain: ChainWithSigners {
    public typealias SpecificSigner = EVMSigners
    public typealias WalletType = EVMWallet
}

extension SolanaChain: ChainWithSigners {
    public typealias SpecificSigner = SolanaSigners
    public typealias WalletType = SolanaWallet
}

extension StellarChain: ChainWithSigners {
    public typealias SpecificSigner = StellarSigners
    public typealias WalletType = StellarWallet
}
