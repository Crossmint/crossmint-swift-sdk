import CrossmintCommonTypes

public protocol CrossmintWallets: Sendable {
    @available(*, deprecated, message: "Use type-safe getOrCreateWallet methods with EVMSigners or SolanaSigners")
    func getOrCreateWallet(
        chain: Chain,
        signer: any Signer,
        options: WalletOptions?
    ) async throws(WalletError) -> Wallet

    func getOrCreateWallet(
        chain: EVMChain,
        signer: EVMSigners,
        options: WalletOptions?
    ) async throws(WalletError) -> Wallet

    func getOrCreateWallet(
        chain: SolanaChain,
        signer: SolanaSigners,
        options: WalletOptions?
    ) async throws(WalletError) -> Wallet

    func getOrCreateWallet(
        chain: StellarChain,
        signer: StellarSigners,
        options: WalletOptions?
    ) async throws(WalletError) -> Wallet
}

extension CrossmintWallets {
    public func getOrCreateWallet(
        chain: EVMChain,
        signer: EVMSigners,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> Wallet {
        try await getOrCreateWallet(
            chain: Chain(chain.name),
            signer: signer.signer,
            options: options
        )
    }

    public func getOrCreateWallet(
        chain: SolanaChain,
        signer: SolanaSigners,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> Wallet {
        try await getOrCreateWallet(
            chain: Chain(chain.name),
            signer: signer.signer,
            options: options
        )
    }

    public func getOrCreateWallet(
        chain: StellarChain,
        signer: StellarSigners,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> Wallet {
        try await getOrCreateWallet(
            chain: Chain(chain.name),
            signer: signer.signer,
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
