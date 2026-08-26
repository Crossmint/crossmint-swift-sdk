import CrossmintCommonTypes

/// Factory for obtaining and creating Crossmint smart wallets.
///
/// Obtain an instance from ``ClientSDK/crossmintWallets()`` or ``CrossmintSDK/crossmintWallets``.
/// Prefer the chain-specific overloads (e.g. ``getWallet(chain:recovery:options:)``)
/// over the generic ones so you get a typed wallet back without an additional cast.
///
/// ## Example
/// ```swift
/// let wallets = CrossmintSDK.shared.crossmintWallets
///
/// // Get or create an EVM wallet with email recovery
/// if let wallet = try await wallets.getWallet(chain: .baseMainnet, recovery: .email("user@example.com")) {
///     print("Existing wallet:", wallet.address)
/// } else {
///     let wallet = try await wallets.createWallet(chain: .baseMainnet, recovery: .email("user@example.com"))
///     print("New wallet:", wallet.address)
/// }
/// ```
public protocol CrossmintWallets: Sendable {
    /// Returns the wallet for the authenticated user on the given chain, or `nil` if none exists yet.
    ///
    /// - Parameters:
    ///   - chain: The blockchain to look up.
    ///   - recovery: The signer that can authorize recovery operations for this wallet.
    ///   - options: Optional configuration, such as enabling a device signer.
    func getWallet(
        chain: Chain,
        recovery: any Signer,
        options: WalletOptions?
    ) async throws(WalletError) -> Wallet?

    /// Creates a new smart wallet for the authenticated user on the given chain.
    ///
    /// Deploys the wallet contract on-chain. Calling this when a wallet already exists
    /// returns the existing wallet rather than creating a duplicate.
    ///
    /// - Parameters:
    ///   - chain: The blockchain to deploy to.
    ///   - recovery: The signer that can authorize recovery operations for this wallet.
    ///   - options: Optional configuration, such as enabling a device signer.
    func createWallet(
        chain: Chain,
        recovery: any Signer,
        options: WalletOptions?
    ) async throws(WalletError) -> Wallet
}

extension CrossmintWallets {
    // MARK: - getWallet convenience overloads

    public func getWallet(
        chain: EVMChain,
        recovery: EVMSigners,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> EVMWallet? {
        guard let wallet = try await getWallet(
            chain: Chain(chain.name),
            recovery: await recovery.signer,
            options: options
        ) else { return nil }
        guard let evmWallet = wallet as? EVMWallet else {
            throw WalletError.walletInvalidType("Expected EVMWallet for chain \(chain.name)")
        }
        return evmWallet
    }

    public func getWallet(
        chain: SolanaChain,
        recovery: SolanaSigners,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> SolanaWallet? {
        guard let wallet = try await getWallet(
            chain: Chain(chain.name),
            recovery: await recovery.signer,
            options: options
        ) else { return nil }
        guard let solanaWallet = wallet as? SolanaWallet else {
            throw WalletError.walletInvalidType("Expected SolanaWallet for chain \(chain.name)")
        }
        return solanaWallet
    }

    public func getWallet(
        chain: StellarChain,
        recovery: StellarSigners,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> StellarWallet? {
        guard let wallet = try await getWallet(
            chain: Chain(chain.name),
            recovery: await recovery.signer,
            options: options
        ) else { return nil }
        guard let stellarWallet = wallet as? StellarWallet else {
            throw WalletError.walletInvalidType("Expected StellarWallet for chain \(chain.name)")
        }
        return stellarWallet
    }

    public func getWallet<C: ChainWithSigners>(
        chain: C,
        recovery: C.SpecificSigner,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> C.WalletType? {
        guard let wallet = try await getWallet(
            chain: Chain(chain.name),
            recovery: await recovery.signer,
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
        recovery: EVMSigners,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> EVMWallet {
        let wallet = try await createWallet(
            chain: Chain(chain.name),
            recovery: await recovery.signer,
            options: options
        )
        guard let evmWallet = wallet as? EVMWallet else {
            throw WalletError.walletInvalidType("Expected EVMWallet for chain \(chain.name)")
        }
        return evmWallet
    }

    public func createWallet(
        chain: SolanaChain,
        recovery: SolanaSigners,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> SolanaWallet {
        let wallet = try await createWallet(
            chain: Chain(chain.name),
            recovery: await recovery.signer,
            options: options
        )
        guard let solanaWallet = wallet as? SolanaWallet else {
            throw WalletError.walletInvalidType("Expected SolanaWallet for chain \(chain.name)")
        }
        return solanaWallet
    }

    public func createWallet(
        chain: StellarChain,
        recovery: StellarSigners,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> StellarWallet {
        let wallet = try await createWallet(
            chain: Chain(chain.name),
            recovery: await recovery.signer,
            options: options
        )
        guard let stellarWallet = wallet as? StellarWallet else {
            throw WalletError.walletInvalidType("Expected StellarWallet for chain \(chain.name)")
        }
        return stellarWallet
    }

    public func createWallet<C: ChainWithSigners>(
        chain: C,
        recovery: C.SpecificSigner,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> C.WalletType {
        let wallet = try await createWallet(
            chain: Chain(chain.name),
            recovery: await recovery.signer,
            options: options
        )
        guard let typed = wallet as? C.WalletType else {
            throw WalletError.walletInvalidType("Unexpected wallet type for chain \(chain.name)")
        }
        return typed
    }
}

/// Configuration for wallet creation and retrieval.
public struct WalletOptions {
    let experimentalCallbacks: ExperimentalCallbacks?

    /// When `true`, a device-bound signing key is generated in the Secure Enclave (or a software
    /// keychain on devices without one) and registered as a delegated signer on the wallet.
    /// Transactions can then be signed without an OTP prompt on that device.
    public let deviceSigner: Bool

    public init(deviceSigner: Bool = false) {
        self.experimentalCallbacks = nil
        self.deviceSigner = deviceSigner
    }

    init(deviceSigner: Bool = false, experimentalCallbacks: ExperimentalCallbacks?) {
        self.deviceSigner = deviceSigner
        self.experimentalCallbacks = experimentalCallbacks
    }
}

protocol ExperimentalCallbacks {
    func onWalletCreationStart()
    func onTransactionStart()
}
