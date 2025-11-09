import CrossmintCommonTypes
import Foundation

public struct GetBalanceQueryParams: Sendable {
    let walletLocator: WalletLocator
    let tokens: [CryptoCurrency]
    let chains: [AnyChain]

    public init(
        walletLocator: WalletLocator,
        tokens: [CryptoCurrency],
        chains: [AnyChain] = []
    ) {
        self.walletLocator = walletLocator
        self.tokens = tokens
        self.chains = chains
    }

    public init(
        walletLocator: WalletLocator,
        token: CryptoCurrency,
        chain: Chain
    ) {
        self.init(walletLocator: walletLocator, tokens: [token], chains: [chain])
    }
}
