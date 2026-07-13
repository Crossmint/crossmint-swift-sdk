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
    /// completed) for the wallet's chain are omitted.
    ///
    /// Always returns fresh data — safe to call after ``addSigner(_:)`` or ``removeSigner(locator:)``.
    public func signers() async throws(WalletError) -> [WalletSigner] {
        Logger.smartWallet.info(LogEvents.walletSignersStart)
        do {
            let model = try await smartWalletService.getWallet(GetMeWalletRequest(chainType: chain.chainType))
            let locators = (model.config.signers ?? []).compactMap { $0.locator ?? $0.signer }
            let signers = await fetchSignerStates(for: locators)
            Logger.smartWallet.info(LogEvents.walletSignersSuccess, attributes: [
                "count": "\(signers.count)"
            ])
            return signers
        } catch {
            Logger.smartWallet.error(LogEvents.walletSignersError, attributes: [
                "error": "\(error)"
            ])
            throw error
        }
    }

    /// Fetches each signer's state concurrently, dropping signers whose lookup fails
    /// so one broken signer doesn't fail the whole list. Preserves the input order.
    private func fetchSignerStates(for locators: [String]) async -> [WalletSigner] {
        let service = smartWalletService
        let chainType = chain.chainType
        let chainName = chain.name
        let states = await withTaskGroup(of: (Int, WalletSigner?).self) { group in
            for (index, locator) in locators.enumerated() {
                group.addTask {
                    let signer = (try? await service.getSigner(
                        locator,
                        chainType: chainType,
                        chainName: chainName
                    )) ?? nil
                    return (index, signer)
                }
            }
            var collected: [(Int, WalletSigner)] = []
            for await (index, signer) in group {
                if let signer {
                    collected.append((index, signer))
                }
            }
            return collected
        }
        return states.sorted { $0.0 < $1.0 }.map(\.1)
    }

    internal let smartWalletService: SmartWalletService
    internal let config: WalletConfig
    internal let blockchainAddress: Address
    internal let signer: any Signer
    internal let chain: Chain
    var deviceSignerKeyStorage: (any DeviceSignerKeyStorage)?
    var deviceSignerService: DeviceSignerService
    var signerRegistrationService: SignerRegistrationService
    var selectedSigner: (any Signer)?
    var selectedSignerLocator: String?
    var _needsRecovery: Bool = false
    var _deviceSignerApproved: Bool = false
    var _deviceSignerUnsupported: Bool = false
    var initialSigners: [WalletSignerConfigApiModel] = []
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
        deviceSignerKeyStorage: (any DeviceSignerKeyStorage)? = nil
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
        self.initialSigners = baseModel.config.signers ?? []
        self.signerInitializationTask = Task { [weak self] in
            await self?.initDefaultSigner()
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
