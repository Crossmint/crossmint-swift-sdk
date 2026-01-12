import CrossmintCommonTypes

extension ChainType {
    var mappingType: any WalletTypeTransactionMapping.Type {
        switch self {
        case .evm:
            return EVMSmartWalletMapping.self
        case .solana:
            return SolanaSmartWalletMapping.self
        case .stellar:
            return StellarSmartWalletMapping.self
        case .unknown:
            // If the chain type is unknown
            return EVMSmartWalletMapping.self
        }
    }
}

extension Optional where Wrapped == ChainType {
    var mappingType: any WalletTypeTransactionMapping.Type {
        switch self {
        case .none:
            return EVMSmartWalletMapping.self
        case .some(let chainType):
            return chainType.mappingType
        }
    }
}
