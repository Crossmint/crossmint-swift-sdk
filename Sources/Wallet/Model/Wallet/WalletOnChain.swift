import CrossmintCommonTypes

public protocol WalletOnChain {
    associatedtype SpecificChain: AnyChain

    func nfts(page: Int, nftsPerPage: Int, on chain: SpecificChain) async throws(WalletError) -> [NFT]

    func fund(
        token: CryptoCurrency,
        amount: Int,
        on chain: SpecificChain
    ) async throws(WalletError)
}

extension WalletOnChain where Self: Wallet {
    public func nfts(page: Int, nftsPerPage: Int, on chain: SpecificChain) async throws(WalletError) -> [NFT] {
        try await smartWalletService.getNFTs(
            .init(walletLocator: .address(blockchainAddress), chain: chain, page: page, perPage: nftsPerPage)
        )
    }

    public func fund(
        token: CryptoCurrency,
        amount: Int,
        on chain: SpecificChain
    ) async throws(WalletError) {
        try await smartWalletService.fund(
            .init(
                token: token.name,
                amount: amount,
                chain: chain.name,
                address: blockchainAddress
            )
        )
    }
}
