import CrossmintCommonTypes
import Logger

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
            Logger.smartWallet.warning(LogEvents.transactionChainTypeUnknownDefaultedToEVM)
            return EVMSmartWalletMapping.self
        }
    }
}
