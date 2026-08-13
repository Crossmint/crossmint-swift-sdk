import CrossmintCommonTypes
import DeviceSigner
import Foundation
import Logger

open class Wallet: @unchecked Sendable {
    public var address: String {
        blockchainAddress.description
    }

    /// Fetches the current list of signers from the API.
    ///
    /// Each ``WalletSigner`` includes its registration ``WalletSigner/status`` on this
    /// wallet's chain. On EVM wallets, signers without a registration entry (pending or
    /// completed) for the wallet's chain are omitted. A signer whose state lookup fails
    /// is returned with ``SignerStatus/unknown`` rather than dropped.
    ///
    /// Always returns fresh data — safe to call after ``addSigner(_:)`` or ``removeSigner(locator:)``.
    public func signers() async throws(WalletError) -> [WalletSigner] {
        try await signerListService.list()
    }

    internal let smartWalletService: SmartWalletService
    internal let config: WalletConfig
    internal let blockchainAddress: Address
    internal let signer: any Signer
    internal let chain: Chain
    var deviceSignerKeyStorage: (any DeviceSignerKeyStorage)?
    var deviceSignerService: DeviceSignerService
    var signerRegistrationService: SignerRegistrationService
    let signerListService: SignerListService
    var selectedSigner: (any Signer)?
    var selectedSignerLocator: String?
    var _needsRecovery: Bool = false
    var _deviceSignerApproved: Bool = false
    var _deviceSignerUnsupported: Bool = false
    var signerInitializationTask: Task<Void, Never>?

    private let owner: Owner?
    private let createdAt: Date

    var onTransactionStart: (() -> Void)?

    internal init(
        smartWalletService: SmartWalletService,
        signer: any Signer,
        baseModel: WalletApiModel,
        chain: Chain,
        address: Address,
        onTransactionStart: (() -> Void)?,
        deviceSignerKeyStorage: (any DeviceSignerKeyStorage)? = nil,
        deviceSignerUnsupported: Bool = false
    ) throws(WalletError) {
        self.smartWalletService = smartWalletService
        self.owner = baseModel.owner
        self.blockchainAddress = address
        self.createdAt = baseModel.createdAt
        self.config = baseModel.config.toDomain
        self.signer = signer
        self.chain = chain
        self.onTransactionStart = onTransactionStart
        self.deviceSignerKeyStorage = deviceSignerKeyStorage
        self.deviceSignerService = DeviceSignerService(
            smartWalletService: smartWalletService,
            chainType: chain.chainType,
            chainName: chain.name,
            address: address.description
        )
        self.signerRegistrationService = SignerRegistrationService(
            smartWalletService: smartWalletService,
            chainType: chain.chainType,
            chainName: chain.name
        )
        self.signerListService = SignerListService(
            smartWalletService: smartWalletService,
            chainType: chain.chainType,
            chainName: chain.name
        )
        self._deviceSignerUnsupported = deviceSignerUnsupported
        let delegatedSigners = baseModel.config.signers ?? []
        self.signerInitializationTask = Task { [weak self] in
            await self?.initDefaultSigner(delegatedSigners: delegatedSigners)
        }
    }

    /// Returns whether the given locator is registered as a signer on this wallet.
    ///
    /// Checks both the wallet signers (via a fresh API call) and the admin signer.
    /// Returns `false` on any network error.
    ///
    /// - Parameter locator: A signer locator string, e.g. `"email:user@example.com"`,
    ///   `"device:<pubkey>"`, `"api-key"`, `"passkey:<id>"`.
    public func signerIsRegistered(_ locator: String) async -> Bool {
        let walletModel: WalletApiModel
        do {
            walletModel = try await smartWalletService.getWallet(GetMeWalletRequest(chainType: chain.chainType))
        } catch {
            return false
        }
        let signerMatch = walletModel.config.signers?
            .contains(where: { $0.locator == locator }) ?? false
        if signerMatch { return true }
        return walletModel.config.recovery.toDomain.locator == locator
    }

    /// Returns the locator of the device signer that keeps its private key on this device.
    /// Returns `nil` if this device has no key, or if the wallet does not support device signers.
    ///
    /// This device keeps only one device key for each wallet. Device signing always uses that key.
    /// Thus this is the only device signer that can sign here.
    public func localDeviceSignerLocator() async -> String? {
        guard let storage = deviceSignerKeyStorage, !_deviceSignerUnsupported else { return nil }
        return await deviceSignerService.locator(for: storage)
    }

    /// Returns whether the given signer is approved and usable on this wallet's chain.
    ///
    /// A freshly registered signer can require approval before it can sign — see ``addSigner(_:)``.
    /// Returns `false` when the signer is not registered on this wallet.
    ///
    /// - Parameter locator: A signer locator string, e.g. `"email:user@example.com"`,
    ///   `"device:<pubkey>"`, `"api-key"`, `"passkey:<id>"`.
    /// - Throws: ``WalletError`` if the request fails.
    public func isSignerApproved(_ locator: String) async throws(WalletError) -> Bool {
        Logger.smartWallet.debug(LogEvents.walletIsSignerApprovedStart)
        let response: AddDelegatedSignerResponse?
        do {
            response = try await smartWalletService.getSigner(locator, chainType: chain.chainType)
        } catch {
            Logger.smartWallet.error(LogEvents.walletIsSignerApprovedError, attributes: [
                "error": "\(error)"
            ])
            throw error
        }
        guard let response else {
            Logger.smartWallet.debug(LogEvents.walletIsSignerApprovedSuccess, attributes: [
                "approved": "false"
            ])
            return false
        }
        let status = registrationStatus(of: response)
        let approved = status == .active
        Logger.smartWallet.debug(LogEvents.walletIsSignerApprovedSuccess, attributes: [
            "approved": "\(approved)"
        ])
        return approved
    }

    /// EVM approval state lives in the per-chain entries; Solana and Stellar approve through
    /// a transaction. An empty `chains` map means the signer was created together with the
    /// wallet and needed no approval.
    private func registrationStatus(of response: AddDelegatedSignerResponse) -> SignerStatus? {
        if chain.chainType == .solana || chain.chainType == .stellar {
            return SignerStatus.from(response.transaction?.status ?? "success")
        }
        guard let chains = response.chains, !chains.isEmpty else {
            return .active
        }
        return chains[chain.name]?.status
    }

    /// Returns a page of NFTs owned by this wallet.
    ///
    /// - Parameters:
    ///   - page: Zero-based page index.
    ///   - nftsPerPage: Number of NFTs per page.
    public func nfts(page: Int, nftsPerPage: Int) async throws(WalletError) -> [NFT] {
        try await smartWalletService.getNFTs(
            .init(walletLocator: .address(blockchainAddress), chain: chain, page: page, perPage: nftsPerPage)
        )
    }

    /// Fetches the transfer history for this wallet.
    ///
    /// Returns a list of incoming and outgoing transfers for the specified tokens.
    /// Use this method to display transaction history in your application.
    ///
    /// - Parameter tokens: The cryptocurrency tokens to fetch transfers for.
    ///   Common values include `.eth`, `.usdc`, `.sol`, etc.
    ///
    /// - Returns: A ``TransferListResult`` containing the transfer events sorted
    ///   by timestamp (most recent first).
    ///
    /// - Throws: ``WalletError`` if the request fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Fetch ETH and USDC transfers
    /// let result = try await wallet.listTransfers(tokens: [.eth, .usdc])
    ///
    /// for transfer in result.transfers {
    ///     switch transfer.type {
    ///     case .outgoing:
    ///         print("Sent \(transfer.amount) \(transfer.tokenSymbol ?? "tokens")")
    ///     case .incoming:
    ///         print("Received \(transfer.amount) \(transfer.tokenSymbol ?? "tokens")")
    ///     case .unknown:
    ///         break
    ///     }
    /// }
    /// ```
    public func listTransfers(
        tokens: [CryptoCurrency]
    ) async throws(WalletError) -> TransferListResult {
        try await smartWalletService.listTransfers(
            ListTransfersQueryParams(
                walletLocator: .address(blockchainAddress),
                chain: chain,
                tokens: tokens
            )
        )
    }

    @available(*, deprecated, renamed: "balances", message: "Use the balances(tokens) instead")
    public func balance(
        of tokens: [CryptoCurrency] = []
    ) async throws(WalletError) -> Balances {
        try await smartWalletService.getBalance(
            .init(
                walletLocator: .address(blockchainAddress),
                tokens: tokens,
                chains: [chain]
            )
        )
    }

    /// Returns balances for the requested tokens, always including the chain's native token and USDC.
    ///
    /// - Parameters:
    ///   - tokens: Additional tokens to include. Native token and USDC are always fetched.
    ///   - chains: Additional chains to query. The wallet's own chain is always included.
    public func balances(
        _ tokens: [CryptoCurrency] = [],
        _ chains: [Chain] = []
    ) async throws(WalletError) -> Balance {
        Logger.smartWallet.debug(LogEvents.walletBalancesStart)

        do {
            let nativeToken = getNativeToken(chain)
            let balances = try await smartWalletService.getBalance(
                .init(
                    walletLocator: .address(blockchainAddress),
                    tokens: tokens + [nativeToken, .usdc],
                    chains: [chain] + chains
                )
            )

            Logger.smartWallet.debug(LogEvents.walletBalancesSuccess)

            return BalanceTransformer.transform(
                from: balances,
                nativeToken: nativeToken,
                requestedTokens: tokens
            )
        } catch {
            Logger.smartWallet.error(LogEvents.walletBalancesError, attributes: [
                "error": "\(error)"
            ])
            throw error
        }
    }

    /// Funds the wallet with test tokens from the Crossmint faucet.
    ///
    /// Only available in staging/development environments; throws in production.
    ///
    /// - Parameters:
    ///   - token: The token to fund.
    ///   - amount: Amount in the token's smallest unit (e.g. lamports for SOL, wei for ETH).
    public func fund(
        token: CryptoCurrency,
        amount: Int
    ) async throws(WalletError) {
        Logger.smartWallet.debug(LogEvents.walletStagingFundStart, attributes: [
            "token": token.name,
            "amount": "\(amount)",
            "chain": chain.name
        ])

        do {
            try await smartWalletService.fund(
                .init(
                    token: token.name,
                    amount: amount,
                    chain: chain.name,
                    address: blockchainAddress
                )
            )

            Logger.smartWallet.debug(LogEvents.walletStagingFundSuccess)
        } catch {
            Logger.smartWallet.error(LogEvents.walletStagingFundError, attributes: [
                "error": "\(error)"
            ])
            throw error
        }
    }

    private func getNativeToken(_ chain: AnyChain) -> CryptoCurrency {
        switch chain.name {
        case SolanaChain.solana.name:
            return .sol
        case StellarChain.stellar.name:
            return .xlm
        default:
            return .eth
        }
    }
}
