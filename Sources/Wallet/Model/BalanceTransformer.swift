import CrossmintCommonTypes
import Foundation

public struct BalanceTransformer {

    @available(
        *,
        deprecated,
        message: "Pass the wallet's chain to receive the available, locked and accounts breakdown"
    )
    public static func transform(
        from balances: Balances,
        nativeToken: CryptoCurrency,
        requestedTokens: [CryptoCurrency]
    ) -> Balance {
        balance(from: balances, nativeToken: nativeToken, requestedTokens: requestedTokens, chain: nil)
    }

    /// - Parameter chain: The chain to report the available, locked and accounts values for.
    public static func transform(
        from balances: Balances,
        nativeToken: CryptoCurrency,
        requestedTokens: [CryptoCurrency],
        chain: Chain
    ) -> Balance {
        balance(from: balances, nativeToken: nativeToken, requestedTokens: requestedTokens, chain: chain)
    }

    private static func balance(
        from balances: Balances,
        nativeToken: CryptoCurrency,
        requestedTokens: [CryptoCurrency],
        chain: Chain?
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
        chain: Chain?
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

        let amount = chainBalances?.reportedAmount ?? "0"
        let decimals = chainBalances?.decimals
        let rawAmount = chainBalances?.reportedRawAmount
        let detail = chain.flatMap { chainBalances?.chainDetails[$0] }

        return TokenBalance(
            symbol: symbol,
            name: currency.name,
            amount: amount,
            contractAddress: nil,
            decimals: decimals,
            rawAmount: rawAmount,
            available: detail?.available,
            locked: detail?.locked,
            accounts: detail?.accounts
        )
    }
}
