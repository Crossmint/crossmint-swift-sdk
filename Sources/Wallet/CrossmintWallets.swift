import CrossmintCommonTypes

/// Factory for obtaining and creating Crossmint smart wallets.
///
/// Obtain an instance from ``ClientSDK/crossmintWallets()`` or ``CrossmintSDK/crossmintWallets``.
/// Prefer the chain-specific overloads (e.g. ``getWallet(chain:options:)``)
/// over the generic ones so you get a typed wallet back without an additional cast.
///
/// ## Example
/// ```swift
/// let wallets = CrossmintSDK.shared.crossmintWallets
///
/// // Get or create an EVM wallet with email recovery
/// if let wallet = try await wallets.getWallet(chain: .baseMainnet) {
///     print("Existing wallet:", wallet.address)
/// } else {
///     let wallet = try await wallets.createWallet(
///         chain: .baseMainnet,
///         recoveryMethods: [.email("user@example.com")]
///     )
///     print("New wallet:", wallet.address)
/// }
///
/// // Solana and Stellar accept several recovery signers. Each one can authorize on its own.
/// let solanaWallet = try await wallets.createWallet(
///     chain: .solana,
///     recoveryMethods: [.email("user@example.com"), .phone("+15551234567")]
/// )
/// ```
public protocol CrossmintWallets: Sendable {
    /// Returns the wallet for the authenticated user on the given chain, or `nil` if none exists yet.
    ///
    /// The wallet's first recovery signer is the active signer until ``Wallet/useSigner(_:)`` selects
    /// another one. When that signer is a passkey or an external wallet, call ``Wallet/useSigner(_:)``
    /// before signing.
    ///
    /// - Parameters:
    ///   - chain: The blockchain to look up.
    ///   - options: Optional configuration, such as enabling a device signer.
    func getWallet(
        chain: Chain,
        options: WalletOptions?
    ) async throws(WalletError) -> Wallet?

    /// Returns the wallet for the authenticated user on the given chain, or `nil` if none exists yet.
    ///
    /// - Parameters:
    ///   - chain: The blockchain to look up.
    ///   - recovery: The signer that can authorize recovery operations for this wallet.
    ///   - options: Optional configuration, such as enabling a device signer.
    @available(*, deprecated, message: "Use getWallet(chain:options:). The recovery signer comes from the API.")
    func getWallet(
        chain: Chain,
        recovery: any Signer,
        options: WalletOptions?
    ) async throws(WalletError) -> Wallet?

    /// Creates a new smart wallet for the authenticated user on the given chain.
    ///
    /// - Parameters:
    ///   - chain: The blockchain to deploy to.
    ///   - recovery: The signer that can authorize recovery operations for this wallet.
    ///   - options: Optional configuration, such as enabling a device signer.
    @available(*, deprecated, message: "Use createWallet(chain:recoveryMethods:options:).")
    func createWallet(
        chain: Chain,
        recovery: any Signer,
        options: WalletOptions?
    ) async throws(WalletError) -> Wallet

    /// Creates a new smart wallet for the authenticated user on the given chain.
    ///
    /// Deploys the wallet contract on-chain. Calling this when a wallet already exists
    /// returns the existing wallet rather than creating a duplicate.
    ///
    /// Each recovery signer can authorize on its own. The wallet stays usable when the user loses
    /// one of them. Only Solana and Stellar accept more than one recovery signer. The wallet's first
    /// recovery signer, as the API reports it, is the active signer until ``Wallet/useSigner(_:)``
    /// selects another one.
    ///
    /// - Parameters:
    ///   - chain: The blockchain to deploy to.
    ///   - recoveryMethods: The signers that can each authorize recovery operations for this wallet.
    ///     To use an external wallet as a recovery signer, pass an ``ExternalWalletSigner``.
    ///   - options: Optional configuration, such as enabling a device signer.
    /// - Throws: ``WalletError/recoveryConfigRejected(code:message:)`` when the list is empty, or has
    ///   more than one signer on a chain that accepts one.
    func createWallet(
        chain: Chain,
        recoveryMethods: [any Signer],
        options: WalletOptions?
    ) async throws(WalletError) -> Wallet
}

extension CrossmintWallets {
    /// Conformers written before this entry point existed get this default. It throws
    /// ``WalletError/walletGeneric(_:)``. Implement ``getWallet(chain:options:)`` to load wallets.
    public func getWallet(
        chain: Chain,
        options: WalletOptions?
    ) async throws(WalletError) -> Wallet? {
        throw .walletGeneric("This CrossmintWallets implementation does not implement getWallet(chain:options:)")
    }

    @available(*, deprecated, message: "Use getWallet(chain:options:). The recovery signer comes from the API.")
    public func getWallet(
        chain: Chain,
        recovery: any Signer,
        options: WalletOptions?
    ) async throws(WalletError) -> Wallet? {
        try await getWallet(chain: chain, options: options)
    }

    /// Conformers that implement only the recovery list entry point get this default. It sends the
    /// signer as a one-entry list, which puts it under `recoveryMethods` on Solana and Stellar.
    @available(*, deprecated, message: "Use createWallet(chain:recoveryMethods:options:).")
    public func createWallet(
        chain: Chain,
        recovery: any Signer,
        options: WalletOptions?
    ) async throws(WalletError) -> Wallet {
        try await createWallet(chain: chain, recoveryMethods: [recovery], options: options)
    }

    // MARK: - getWallet convenience overloads

    public func getWallet(
        chain: EVMChain,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> EVMWallet? {
        guard let wallet = try await getWallet(chain: Chain(chain.name), options: options) else { return nil }
        guard let evmWallet = wallet as? EVMWallet else {
            throw WalletError.walletInvalidType("Expected EVMWallet for chain \(chain.name)")
        }
        return evmWallet
    }

    public func getWallet(
        chain: SolanaChain,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> SolanaWallet? {
        guard let wallet = try await getWallet(chain: Chain(chain.name), options: options) else { return nil }
        guard let solanaWallet = wallet as? SolanaWallet else {
            throw WalletError.walletInvalidType("Expected SolanaWallet for chain \(chain.name)")
        }
        return solanaWallet
    }

    public func getWallet(
        chain: StellarChain,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> StellarWallet? {
        guard let wallet = try await getWallet(chain: Chain(chain.name), options: options) else { return nil }
        guard let stellarWallet = wallet as? StellarWallet else {
            throw WalletError.walletInvalidType("Expected StellarWallet for chain \(chain.name)")
        }
        return stellarWallet
    }

    public func getWallet<C: ChainWithSigners>(
        chain: C,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> C.WalletType? {
        guard let wallet = try await getWallet(chain: Chain(chain.name), options: options) else { return nil }
        guard let typed = wallet as? C.WalletType else {
            throw WalletError.walletInvalidType("Unexpected wallet type for chain \(chain.name)")
        }
        return typed
    }

    // MARK: - Deprecated getWallet overloads

    @available(*, deprecated, message: "Use getWallet(chain:options:). The recovery signer comes from the API.")
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

    @available(*, deprecated, message: "Use getWallet(chain:options:). The recovery signer comes from the API.")
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

    @available(*, deprecated, message: "Use getWallet(chain:options:). The recovery signer comes from the API.")
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

    @available(*, deprecated, message: "Use getWallet(chain:options:). The recovery signer comes from the API.")
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

    /// Creates a wallet with several recovery signers. Each one can authorize on its own. Only
    /// Solana and Stellar accept more than one.
    ///
    /// The wallet's first recovery signer, as the API reports it, is the active signer until
    /// ``Wallet/useSigner(_:)`` selects another one.
    /// - Throws: ``WalletError/recoveryConfigRejected(code:message:)`` when the list is empty, or has more than
    ///   one signer on a chain that accepts one.
    public func createWallet<C: ChainWithSigners>(
        chain: C,
        recoveryMethods: [C.SpecificSigner],
        options: WalletOptions? = nil
    ) async throws(WalletError) -> C.WalletType {
        let wallet = try await createWallet(
            chain: Chain(chain.name),
            recoveryMethods: await signers(recoveryMethods),
            options: options
        )
        guard let typed = wallet as? C.WalletType else {
            throw WalletError.walletInvalidType("Unexpected wallet type for chain \(chain.name)")
        }
        return typed
    }

    // MARK: - Deprecated createWallet overloads

    @available(*, deprecated, message: "Use createWallet(chain:recoveryMethods:options:).")
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

    @available(*, deprecated, message: "Use createWallet(chain:recoveryMethods:options:).")
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

    @available(*, deprecated, message: "Use createWallet(chain:recoveryMethods:options:).")
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

    @available(*, deprecated, message: "Use createWallet(chain:recoveryMethods:options:).")
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

    @MainActor
    private func signers(_ providers: [any SignerProvider]) -> [any Signer] {
        providers.map(\.signer)
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
