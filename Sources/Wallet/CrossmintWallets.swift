import CrossmintCommonTypes
import DeviceSigner

public protocol CrossmintWallets: Sendable {
    func getWallet(
        chain: Chain,
        signer: any Signer,
        options: WalletOptions?
    ) async throws(WalletError) -> Wallet

    func createWallet(
        chain: Chain,
        signer: any Signer,
        options: WalletOptions?
    ) async throws(WalletError) -> Wallet
}

extension CrossmintWallets {
    // MARK: - getWallet convenience overloads

    public func getWallet(
        chain: EVMChain,
        signer: EVMSigners,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> Wallet {
        try await getWallet(
            chain: Chain(chain.name),
            signer: await signer.signer,
            options: options
        )
    }

    public func getWallet(
        chain: SolanaChain,
        signer: SolanaSigners,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> Wallet {
        try await getWallet(
            chain: Chain(chain.name),
            signer: await signer.signer,
            options: options
        )
    }

    public func getWallet(
        chain: StellarChain,
        signer: StellarSigners,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> Wallet {
        try await getWallet(
            chain: Chain(chain.name),
            signer: await signer.signer,
            options: options
        )
    }

    public func getWallet<C: ChainWithSigners>(
        chain: C,
        signer: C.SpecificSigner,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> Wallet {
        try await getWallet(
            chain: Chain(chain.name),
            signer: await signer.signer,
            options: options
        )
    }

    // MARK: - createWallet convenience overloads

    public func createWallet(
        chain: EVMChain,
        signer: EVMSigners,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> Wallet {
        try await createWallet(
            chain: Chain(chain.name),
            signer: await signer.signer,
            options: options
        )
    }

    public func createWallet(
        chain: SolanaChain,
        signer: SolanaSigners,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> Wallet {
        try await createWallet(
            chain: Chain(chain.name),
            signer: await signer.signer,
            options: options
        )
    }

    public func createWallet(
        chain: StellarChain,
        signer: StellarSigners,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> Wallet {
        try await createWallet(
            chain: Chain(chain.name),
            signer: await signer.signer,
            options: options
        )
    }

    public func createWallet<C: ChainWithSigners>(
        chain: C,
        signer: C.SpecificSigner,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> Wallet {
        try await createWallet(
            chain: Chain(chain.name),
            signer: await signer.signer,
            options: options
        )
    }
}

public struct WalletOptions {
    let experimentalCallbacks: ExperimentalCallbacks?
    public let deviceSigner: DeviceSignerOptions?

    public init(deviceSigner: DeviceSignerOptions? = nil) {
        self.experimentalCallbacks = nil
        self.deviceSigner = deviceSigner
    }

    init(deviceSigner: DeviceSignerOptions? = nil, experimentalCallbacks: ExperimentalCallbacks?) {
        self.deviceSigner = deviceSigner
        self.experimentalCallbacks = experimentalCallbacks
    }
}

protocol ExperimentalCallbacks {
    func onWalletCreationStart()
    func onTransactionStart()
}
