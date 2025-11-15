import CrossmintCommonTypes
import Foundation

public struct BalanceTransformer {

    public static func transform(
        from balances: Balances,
        nativeToken: CryptoCurrency,
        requestedTokens: [CryptoCurrency]
    ) -> Balance {
        let nativeTokenBalance = createTokenBalance(
            from: balances[nativeToken],
            currency: nativeToken
        )

        let usdcBalance = createTokenBalance(
            from: balances[.usdc],
            currency: .usdc
        )

        let additionalTokens = requestedTokens.compactMap { token in
            token != nativeToken && token != .usdc
                ? createTokenBalance(from: balances[token], currency: token)
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
        currency: CryptoCurrency
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

        let amount = chainBalances?.total.description ?? "0"
        let decimals = chainBalances?.decimals
        let rawAmount = chainBalances?.convertToBaseUnits(amount)

        return TokenBalance(
            symbol: symbol,
            name: currency.name,
            amount: amount,
            contractAddress: nil,
            decimals: decimals,
            rawAmount: rawAmount
        )
    }
}
