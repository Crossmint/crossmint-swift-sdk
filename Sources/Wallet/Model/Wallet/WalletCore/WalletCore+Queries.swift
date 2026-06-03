import CrossmintCommonTypes
import Logger

extension WalletCore {
    func balances(_ tokens: [CryptoCurrency] = [], _ chains: [Chain] = []) async throws(WalletError) -> Balance {
        Logger.smartWallet.debug(LogEvents.walletBalancesStart)
        let native = nativeToken(for: chain)
        do {
            let balances = try await smartWalletService.getBalance(.init(
                walletLocator: locator,
                tokens: tokens + [native, .usdc],
                chains: [chain] + chains
            ))
            Logger.smartWallet.debug(LogEvents.walletBalancesSuccess)
            return BalanceTransformer.transform(from: balances, nativeToken: native, requestedTokens: tokens)
        } catch {
            Logger.smartWallet.error(LogEvents.walletBalancesError, attributes: ["error": "\(error)"])
            throw error
        }
    }

    func nfts(page: Int, perPage: Int) async throws(WalletError) -> [NFT] {
        try await smartWalletService.getNFTs(.init(walletLocator: locator, chain: chain, page: page, perPage: perPage))
    }

    func signers() async throws(WalletError) -> [WalletDelegatedSignerConfigApiModel] {
        let model = try await smartWalletService.getWallet(GetMeWalletRequest(chainType: chain.chainType))
        return model.config.signers ?? []
    }

    func listTransfers(tokens: [CryptoCurrency]) async throws(WalletError) -> TransferListResult {
        try await smartWalletService.listTransfers(ListTransfersQueryParams(walletLocator: locator, chain: chain, tokens: tokens))
    }

    // MARK: - Private

    private func nativeToken(for chain: any AnyChain) -> CryptoCurrency {
        switch chain.name {
        case SolanaChain.solana.name: return .sol
        case StellarChain.stellar.name: return .xlm
        default: return .eth
        }
    }
}
