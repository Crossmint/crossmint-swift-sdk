import CrossmintCommonTypes
import Foundation

struct BalanceTransformer {

    static func transform(
        from balances: Balances,
        nativeToken: CryptoCurrency,
        requestedTokens: [CryptoCurrency],
        chain: Chain
    ) -> Balance {
        let nativeTokenBalance = createTokenBalance(
            from: balances[nativeToken],
            currency: nativeToken,
            chain: chain
        )

        let usdcBalance = createTokenBalance(
            from: balances[.usdc],
            currency: .usdc,
            chain: chain
        )

        let additionalTokens = requestedTokens.compactMap { token in
            token != nativeToken && token != .usdc
                ? createTokenBalance(from: balances[token], currency: token, chain: chain)
                : nil
        }

        return Balance(
            nativeToken: nativeTokenBalance,
            usdc: usdcBalance,
            tokens: additionalTokens
        )
    }

    private static func createTokenBalance(
        from chainBalances: ChainBalances?,
        currency: CryptoCurrency,
        chain: Chain
    ) -> TokenBalance {
        let symbol: TokenBalance.Symbol
        switch currency {
        case .eth:
            symbol = .eth
        case .sol:
            symbol = .sol
        case .usdc:
            symbol = .usdc
        default:
            symbol = .symbol(currency.name)
        }

        let detail = chainBalances?.chainDetails[chain]

        return TokenBalance(
            symbol: symbol,
            name: currency.name,
            amount: chainBalances?.reportedAmount ?? "0",
            contractAddress: nil,
            decimals: chainBalances?.decimals,
            rawAmount: chainBalances?.reportedRawAmount,
            available: detail?.available,
            locked: detail?.locked,
            accounts: detail?.accounts
        )
    }
}
