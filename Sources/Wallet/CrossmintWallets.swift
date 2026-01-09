import CrossmintCommonTypes

public protocol CrossmintWallets: Sendable {
    @available(*, deprecated, message: "Use type-safe getOrCreateWallet methods with EVMSigners or SolanaSigners")
    func getOrCreateWallet(
        chain: Chain,
        signer: any Signer,
        options: WalletOptions?
    ) async throws(WalletError) -> Wallet

    func getOrCreateWallet<C: ChainWithSigners>(
        chain: C,
        signer: C.SpecificSigner,
        options: WalletOptions?
    ) async throws(WalletError) -> Wallet
}

extension CrossmintWallets {
    public func getOrCreateWallet<C: ChainWithSigners>(
        chain: C,
        signer: C.SpecificSigner,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> Wallet {
        try await getOrCreateWallet(
            chain: Chain(chain.name),
            signer: await signer.signer,
            options: options
        )
    }
}

public struct WalletOptions {
    let experimentalCallbacks: ExperimentalCallbacks
}

protocol ExperimentalCallbacks {
    func onWalletCreationStart()
    func onTransactionStart()
}
