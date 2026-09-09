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
///
/// // Solana and Stellar accept several recovery signers. Each one can authorize on its own.
/// let solanaWallet = try await wallets.createWallet(
///     chain: .solana,
///     recovery: [.email("user@example.com"), .phone("+15551234567")]
/// )
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

    /// Returns the wallet for the authenticated user on the given chain, or `nil` if none exists yet.
    ///
    /// The first signer in `recovery` is the active signer until ``Wallet/useSigner(_:)`` selects
    /// another one.
    ///
    /// - Parameters:
    ///   - chain: The blockchain to look up.
    ///   - recovery: The signers that can each authorize recovery operations for this wallet.
    ///   - options: Optional configuration, such as enabling a device signer.
    func getWallet(
        chain: Chain,
        recovery: [any Signer],
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

    /// Creates a new smart wallet with several recovery signers for the authenticated user.
    ///
    /// Each recovery signer can authorize on its own, so the wallet stays usable when one of
    /// them is lost. Only Solana and Stellar accept more than one recovery signer. The first
    /// signer in `recovery` is the active signer until ``Wallet/useSigner(_:)`` selects another one.
    ///
    /// - Parameters:
    ///   - chain: The blockchain to deploy to.
    ///   - recovery: The signers that can each authorize recovery operations for this wallet.
    ///   - options: Optional configuration, such as enabling a device signer.
    /// - Throws: ``WalletError/recoveryConfigRejected(code:message:)`` when the list is not
    ///   accepted for this chain.
    func createWallet(
        chain: Chain,
        recovery: [any Signer],
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
        let signer = await recovery.signer
        guard let wallet = try await getWallet(chain: Chain(chain.name), recovery: signer, options: options) else {
            return nil
        }
        return try typed(wallet, for: chain)
    }

    public func getWallet(
        chain: SolanaChain,
        recovery: SolanaSigners,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> SolanaWallet? {
        let signer = await recovery.signer
        guard let wallet = try await getWallet(chain: Chain(chain.name), recovery: signer, options: options) else {
            return nil
        }
        return try typed(wallet, for: chain)
    }

    public func getWallet(
        chain: StellarChain,
        recovery: StellarSigners,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> StellarWallet? {
        let signer = await recovery.signer
        guard let wallet = try await getWallet(chain: Chain(chain.name), recovery: signer, options: options) else {
            return nil
        }
        return try typed(wallet, for: chain)
    }

    public func getWallet<C: ChainWithSigners>(
        chain: C,
        recovery: C.SpecificSigner,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> C.WalletType? {
        let signer = await recovery.signer
        guard let wallet = try await getWallet(chain: Chain(chain.name), recovery: signer, options: options) else {
            return nil
        }
        return try typed(wallet, for: chain)
    }

    /// Returns the authenticated user's wallet, or `nil` if none exists yet, using several recovery
    /// signers. Each one can authorize on its own. Only Solana and Stellar accept more than one.
    ///
    /// The first signer in `recovery` is the active signer until ``Wallet/useSigner(_:)`` selects another one.
    /// - Throws: ``WalletError/recoveryConfigRejected(code:message:)`` when the chain takes a single signer.
    public func getWallet<C: ChainWithSigners>(
        chain: C,
        recovery: [C.SpecificSigner],
        options: WalletOptions? = nil
    ) async throws(WalletError) -> C.WalletType? {
        let signers = await signers(recovery)
        guard let wallet = try await getWallet(chain: Chain(chain.name), recovery: signers, options: options) else {
            return nil
        }
        return try typed(wallet, for: chain)
    }

    // MARK: - createWallet convenience overloads

    public func createWallet(
        chain: EVMChain,
        recovery: EVMSigners,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> EVMWallet {
        let signer = await recovery.signer
        let wallet = try await createWallet(chain: Chain(chain.name), recovery: signer, options: options)
        return try typed(wallet, for: chain)
    }

    public func createWallet(
        chain: SolanaChain,
        recovery: SolanaSigners,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> SolanaWallet {
        let signer = await recovery.signer
        let wallet = try await createWallet(chain: Chain(chain.name), recovery: signer, options: options)
        return try typed(wallet, for: chain)
    }

    public func createWallet(
        chain: StellarChain,
        recovery: StellarSigners,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> StellarWallet {
        let signer = await recovery.signer
        let wallet = try await createWallet(chain: Chain(chain.name), recovery: signer, options: options)
        return try typed(wallet, for: chain)
    }

    public func createWallet<C: ChainWithSigners>(
        chain: C,
        recovery: C.SpecificSigner,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> C.WalletType {
        let signer = await recovery.signer
        let wallet = try await createWallet(chain: Chain(chain.name), recovery: signer, options: options)
        return try typed(wallet, for: chain)
    }

    /// Creates a wallet with several recovery signers. Each one can authorize on its own. Only
    /// Solana and Stellar accept more than one.
    ///
    /// The first signer in `recovery` is the active signer until ``Wallet/useSigner(_:)`` selects another one.
    /// - Throws: ``WalletError/recoveryConfigRejected(code:message:)`` when the chain takes a single signer.
    public func createWallet<C: ChainWithSigners>(
        chain: C,
        recovery: [C.SpecificSigner],
        options: WalletOptions? = nil
    ) async throws(WalletError) -> C.WalletType {
        let signers = await signers(recovery)
        let wallet = try await createWallet(chain: Chain(chain.name), recovery: signers, options: options)
        return try typed(wallet, for: chain)
    }

    @MainActor
    private func signers(_ providers: [any SignerProvider]) -> [any Signer] {
        providers.map(\.signer)
    }

    private func typed<W: Wallet>(_ wallet: Wallet, for chain: some SpecificChain) throws(WalletError) -> W {
        guard let typed = wallet as? W else {
            throw WalletError.walletInvalidType("Expected \(W.self) for chain \(chain.name)")
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
