import CrossmintCommonTypes
import DeviceSigner

public protocol CrossmintWallets: Sendable {
    func getWallet(
        chain: Chain,
        signer: any Signer,
        options: WalletOptions?
    ) async throws(WalletError) -> Wallet?

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
    ) async throws(WalletError) -> EVMWallet? {
        guard let wallet = try await getWallet(
            chain: Chain(chain.name),
            signer: await signer.signer,
            options: options
        ) else { return nil }
        guard let evmWallet = wallet as? EVMWallet else {
            throw WalletError.walletInvalidType("Expected EVMWallet for chain \(chain.name)")
        }
        return evmWallet
    }

    public func getWallet(
        chain: SolanaChain,
        signer: SolanaSigners,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> SolanaWallet? {
        guard let wallet = try await getWallet(
            chain: Chain(chain.name),
            signer: await signer.signer,
            options: options
        ) else { return nil }
        guard let solanaWallet = wallet as? SolanaWallet else {
            throw WalletError.walletInvalidType("Expected SolanaWallet for chain \(chain.name)")
        }
        return solanaWallet
    }

    public func getWallet(
        chain: StellarChain,
        signer: StellarSigners,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> StellarWallet? {
        guard let wallet = try await getWallet(
            chain: Chain(chain.name),
            signer: await signer.signer,
            options: options
        ) else { return nil }
        guard let stellarWallet = wallet as? StellarWallet else {
            throw WalletError.walletInvalidType("Expected StellarWallet for chain \(chain.name)")
        }
        return stellarWallet
    }

    public func getWallet<C: ChainWithSigners>(
        chain: C,
        signer: C.SpecificSigner,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> C.WalletType? {
        guard let wallet = try await getWallet(
            chain: Chain(chain.name),
            signer: await signer.signer,
            options: options
        ) else { return nil }
        guard let typed = wallet as? C.WalletType else {
            throw WalletError.walletInvalidType("Unexpected wallet type for chain \(chain.name)")
        }
        return typed
    }

    // MARK: - createWallet convenience overloads

    public func createWallet(
        chain: EVMChain,
        signer: EVMSigners,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> EVMWallet {
        let wallet = try await createWallet(
            chain: Chain(chain.name),
            signer: await signer.signer,
            options: options
        )
        guard let evmWallet = wallet as? EVMWallet else {
            throw WalletError.walletInvalidType("Expected EVMWallet for chain \(chain.name)")
        }
        return evmWallet
    }

    public func createWallet(
        chain: SolanaChain,
        signer: SolanaSigners,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> SolanaWallet {
        let wallet = try await createWallet(
            chain: Chain(chain.name),
            signer: await signer.signer,
            options: options
        )
        guard let solanaWallet = wallet as? SolanaWallet else {
            throw WalletError.walletInvalidType("Expected SolanaWallet for chain \(chain.name)")
        }
        return solanaWallet
    }

    public func createWallet(
        chain: StellarChain,
        signer: StellarSigners,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> StellarWallet {
        let wallet = try await createWallet(
            chain: Chain(chain.name),
            signer: await signer.signer,
            options: options
        )
        guard let stellarWallet = wallet as? StellarWallet else {
            throw WalletError.walletInvalidType("Expected StellarWallet for chain \(chain.name)")
        }
        return stellarWallet
    }

    public func createWallet<C: ChainWithSigners>(
        chain: C,
        signer: C.SpecificSigner,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> C.WalletType {
        let wallet = try await createWallet(
            chain: Chain(chain.name),
            signer: await signer.signer,
            options: options
        )
        guard let typed = wallet as? C.WalletType else {
            throw WalletError.walletInvalidType("Unexpected wallet type for chain \(chain.name)")
        }
        return typed
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
