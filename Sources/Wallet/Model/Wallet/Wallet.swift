// swiftlint:disable file_length
import CrossmintCommonTypes
import CryptoKit
import DeviceSigner
import Foundation
import Logger
import Web

// swiftlint:disable:next type_body_length
open class Wallet: @unchecked Sendable {
    public var address: String {
        blockchainAddress.description
    }

    /// Fetches the current list of delegated signers from the API.
    ///
    /// Always returns fresh data — safe to call after ``addSigner(_:)`` or ``removeSigner(locator:)``.
    public func signers() async throws(WalletError) -> [WalletDelegatedSignerConfigApiModel] {
        let model = try await smartWalletService.getWallet(GetMeWalletRequest(chainType: chain.chainType))
        return model.config.signers ?? []
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
    var initialDelegatedSigners: [WalletDelegatedSignerConfigApiModel] = []
    var signerInitializationTask: Task<Void, Never>?

    private let owner: Owner?
    private let createdAt: Date

    private var locator: WalletLocator {
        .address(blockchainAddress)
    }

    private var onTransactionStart: (() -> Void)?

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
        self.initialDelegatedSigners = baseModel.config.signers ?? []
        self.signerInitializationTask = Task { [weak self] in
            await self?.initDefaultSigner()
        }
    }

    /// Returns whether the given locator is registered as a signer on this wallet.
    ///
    /// Checks both delegated signers (via a fresh API call) and the admin signer.
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
        let delegatedMatch = walletModel.config.signers?
            .contains(where: { $0.locator == locator }) ?? false
        if delegatedMatch { return true }
        return walletModel.config.recovery.toDomain.locator == locator
    }

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

    public func approve(transactionId id: String) async throws(TransactionError) -> Transaction {
        Logger.smartWallet.info(LogEvents.walletApproveStart, attributes: [
            "transactionId": id
        ])

        do {
            try await preAuthIfNeeded()
        } catch {
            throw .transactionGeneric(error.errorMessage)
        }

        do {
            let transaction = try await self.transaction(withId: id)
            guard let signedTransaction = try await signAndPollWhilePending(transaction) else {
                throw TransactionError.transactionGeneric("Unknown error")
            }

            Logger.smartWallet.info(LogEvents.walletApproveSuccessTransaction, attributes: [
                "transactionId": signedTransaction.id
            ])

            return signedTransaction
        } catch {
            Logger.smartWallet.error(LogEvents.walletApproveError, attributes: [
                "transactionId": id,
                "error": "\(error)"
            ])
            throw error as? TransactionError ?? .transactionGeneric("Unknown error")
        }
    }

    /// Removes an assigned signer from this wallet.
    ///
    /// Submits a remove-signer transaction on-chain. If the transaction requires approval,
    /// the current signer signs it automatically before polling for completion.
    ///
    /// - Parameter locator: The signer locator string identifying the signer to remove
    ///   (e.g. `"device:ABC123..."`, `"external-wallet:0x456..."`).
    /// - Returns: The completed ``Transaction`` once the signer has been removed on-chain.
    /// - Throws: ``TransactionError`` if the request fails or the transaction is rejected.
    public func removeSigner(locator: String) async throws(TransactionError) -> Transaction {
        Logger.smartWallet.info(LogEvents.walletRemoveSignerStart, attributes: [
            "locator": locator
        ])

        do {
            onTransactionStart?()
            let transactionModel = try await smartWalletService.removeSigner(
                locator,
                chainType: chain.chainType,
                chainName: chain.name
            )
            guard let transaction = transactionModel.toDomain(withService: smartWalletService) else {
                throw TransactionError.transactionGeneric("Failed to parse remove signer response")
            }
            guard let result = try await signAndPollWhilePending(transaction) else {
                throw TransactionError.transactionGeneric("Unknown error")
            }
            Logger.smartWallet.info(LogEvents.walletRemoveSignerSuccess, attributes: [
                "locator": locator
            ])
            return result
        } catch {
            Logger.smartWallet.error(LogEvents.walletRemoveSignerError, attributes: [
                "locator": locator,
                "error": "\(error)"
            ])
            throw error as? TransactionError ?? .transactionGeneric("Unknown error")
        }
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

    @available(*, deprecated, renamed: "send(_:_:_:)", message: "Use the new send method. This one will be removed.")
    public func send(
        token: CryptoCurrency,
        recipient: TransferTokenRecipient,
        amount: String
    ) async throws(TransactionError) -> Transaction {
        Logger.smartWallet.debug(LogEvents.walletSendStart, attributes: [
            "token": token.name,
            "recipient": recipient.description,
            "amount": amount
        ])

        let transferTokenLocator: TransferTokenLocator
        if let evmChain = EVMChain(chain.name) {
            transferTokenLocator = .currency(.evm(evmChain, token))
        } else if let solanaToken = SolanaSupportedToken.toSolanaSupportedToken(token) {
            transferTokenLocator = .currency(.solana(solanaToken))
        } else if let stellarToken = StellarSupportedToken.toStellarSupportedToken(token) {
            transferTokenLocator = .currency(.stellar(stellarToken))
        } else {
            Logger.smartWallet.error(LogEvents.walletSendError, attributes: [
                "error": "Transaction creation failed"
            ])
            throw .transactionCreationFailed
        }

        guard let transaction = try await transferTokenAndPollWhilePending(
            tokenLocator: transferTokenLocator.description,
            recipient: recipient.description,
            amount: amount
        ) else {
            Logger.smartWallet.error(LogEvents.walletSendError, attributes: [
                "error": "Unknown error"
            ])
            throw TransactionError.transactionGeneric("Unknown error")
        }

        Logger.smartWallet.debug(LogEvents.walletSendSuccess, attributes: [
            "transactionId": transaction.id
        ])

        return transaction
    }

    /// Sends tokens to a recipient.
    /// - Parameters:
    ///   - walletLocator: The recipient wallet address
    ///   - tokenLocator: Token identifier in format "{chain}:{token}" (e.g., "base-sepolia:eth", "solana:usdc")
    ///   - amount: The amount to send as a decimal number
    ///   - idempotencyKey: Optional unique key to prevent duplicate transaction creation. If not provided, a random UUID will be generated.
    /// - Returns: A TransactionSummary containing the transaction details
    public func send(
        _ walletLocator: String,
        _ tokenLocator: String,
        _ amount: Double,
        idempotencyKey: String? = nil
    ) async throws(TransactionError) -> TransactionSummary {
        Logger.smartWallet.debug(LogEvents.walletSendStart, attributes: [
            "recipient": walletLocator,
            "tokenLocator": tokenLocator,
            "amount": "\(amount)"
        ])

        guard let transaction = try await transferTokenAndPollWhilePending(
            tokenLocator: tokenLocator,
            recipient: walletLocator,
            amount: String(amount),
            idempotencyKey: idempotencyKey
        )?.toCompleted() else {
            Logger.smartWallet.error(LogEvents.walletSendError, attributes: [
                "error": "Unknown error"
            ])
            throw TransactionError.transactionGeneric("Unknown error")
        }

        Logger.smartWallet.debug(LogEvents.walletSendSuccess, attributes: [
            "transactionId": transaction.id
        ])

        return transaction.summary
    }

    public func transferToken(
        tokenId: String? = nil,
        recipient: TransferTokenRecipient,
        amount: String
    ) async throws(TransactionError) -> Transaction {
        guard let tokenLocator = getTransferTokenLocator(
            fromChain: chain,
            andTokenId: tokenId
        ) else {
            throw .transactionCreationFailed
        }

        guard let transaction = try await transferTokenAndPollWhilePending(
            tokenLocator: tokenLocator.description,
            recipient: recipient.description,
            amount: amount
        ) else { throw TransactionError.transactionGeneric("Unknown error") }

        return transaction
    }

    internal func sendTransaction(
        _ transactionRequest: any TransactionRequest
    ) async throws(TransactionError) -> Transaction? {
        do { try await preAuthIfNeeded() } catch {
            throw .transactionGeneric(error.errorMessage)
        }
        onTransactionStart?()
        let createdTransaction = try await createTransaction(transactionRequest)
        let signedTransaction = try await signTransactionIfRequired(createdTransaction)

        do {
            return try await pollTransactionWhilePending(transaction: signedTransaction)
        } catch {
            switch error {
            case .serviceError(let crossmintServiceError):
                if case .invalidApiKey = crossmintServiceError {
                    Logger.smartWallet.warn(
                        """
Transaction polling skipped due to insufficient API key permissions.
Transaction was submitted successfully but status cannot be verified.
Transaction ID: \(createdTransaction?.id ?? "unknown")
"""
                    )
                    return createdTransaction
                } else {
                    throw error
                }
            default:
                throw error
            }
        }
    }

    internal func transferTokenAndPollWhilePending(
        tokenLocator: String,
        recipient: String,
        amount: String,
        idempotencyKey: String? = nil
    ) async throws(TransactionError) -> Transaction? {
        do { try await preAuthIfNeeded() } catch {
            throw .transactionGeneric(error.errorMessage)
        }
        onTransactionStart?()
        if let storage = deviceSignerKeyStorage {
            await deviceSignerService.ensureRegistered(storage: storage, signer: await updateSignerIfRequired())
        }
        let signerLocator: String?
        if let active = selectedSignerLocator {
            signerLocator = active
        } else if let storage = deviceSignerKeyStorage {
            signerLocator = await deviceSignerService.locator(for: storage)
        } else {
            signerLocator = nil
        }
        let createdTransaction = try await smartWalletService.transferToken(TransferTokenRequest(
            chainType: chain.chainType,
            tokenLocator: tokenLocator,
            recipient: recipient,
            amount: amount,
            signer: signerLocator,
            idempotencyKey: idempotencyKey
        )).toDomain(withService: smartWalletService)

        let signedTransaction = try await signTransactionIfRequired(createdTransaction)
        return try await pollTransactionWhilePending(transaction: signedTransaction)
    }

    internal func signAndPollWhilePending(
        _ transaction: Transaction?
    ) async throws(TransactionError) -> Transaction? {
        let signedTransaction = try await signTransactionIfRequired(transaction)
        return try await pollTransactionWhilePending(transaction: signedTransaction)
    }

    internal func getTransferTokenLocator(
        fromChain chain: AnyChain,
        andTokenId tokenId: String?
    ) -> TransferTokenLocator? {
        if let tokenId {
            switch blockchainAddress {
            case .evm(let evmAddress):
                guard let evmBlockchain = EVMChain(chain.name) else {
                    return nil
                }
                return .tokenId(.evm(evmBlockchain, evmAddress), tokenId: tokenId)
            case .solana(let solanaAddress):
                return .tokenId(.solana(solanaAddress), tokenId: tokenId)
            case .stellar(let stellarAddress):
                return .tokenId(.stellar(stellarAddress), tokenId: tokenId)
            }
        } else {
            switch blockchainAddress {
            case .evm(let evmAddress):
                guard let evmBlockchain = EVMChain(chain.name) else {
                    return nil
                }
                return .address(.evm(evmBlockchain, evmAddress))
            case .solana(let solanaAddress):
                return .address(.solana(solanaAddress))
            case .stellar(let stellarAddress):
                return .address(.stellar(stellarAddress))
            }
        }
    }

    internal func updateSignerIfRequired() async -> any Signer {
        var updatedSigner: any Signer = signer
        if let passkey = config.recovery as? PasskeySignerData {
            if let passkeySigner = updatedSigner as? PasskeySigner {
                updatedSigner = await passkeySigner.updateAdminSigner(
                    passkey
                )
            }
        }
        return updatedSigner
    }

    private func transaction(withId id: String) async throws(TransactionError) -> Transaction {
        guard let transaction = try await smartWalletService.fetchTransaction(
                .init(transactionId: id, chainType: chain.chainType),
        ).toDomain(withService: smartWalletService) else {
            throw TransactionError.transactionGeneric("Unknown error")
        }
        return transaction
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func approveTransaction(
        transactionId: String,
        signerLocator: String,
        message: String
    ) async throws(TransactionError) {
        if signerLocator.hasPrefix("device:") && deviceSignerKeyStorage == nil {
            throw TransactionError.transactionSigningFailed(DeviceSignerError.keyNotFound)
        }
        if signerLocator.hasPrefix("device:"), let storage = deviceSignerKeyStorage {
            let request: SignRequestApi
            do {
                request = try await deviceSignerService.buildSignRequest(
                    signerLocator: signerLocator, message: message, storage: storage
                )
            } catch {
                throw TransactionError.transactionSigningFailed(error)
            }
            _ = try await smartWalletService.signTransaction(
                .init(transactionId: transactionId, apiRequest: request, chainType: chain.chainType)
            )
            return
        }

        let request: SignRequestApi
        do {
            let updatedSigner: any Signer
            if let active = selectedSigner {
                updatedSigner = active
            } else {
                updatedSigner = await updateSignerIfRequired()
            }
            try await updatedSigner.initialize(smartWalletService)
            request = SignRequestApi(
                approvals: try await updatedSigner.approvals(
                    withSignature: try await updatedSigner.sign(message: message)
                )
            )
        } catch {
            switch error {
            case .invalidMessage:
                throw .transactionSigningFailedNoMessage
            case .invalidPrivateKey:
                throw .transactionSigningFailedInvalidKey
            case .cancelled:
                throw .userCancelled
            case .passkey(let passkeyError):
                switch passkeyError {
                case .cancelled:
                    throw .userCancelled
                default:
                    throw .transactionSigningFailed(error)
                }
            case .signingFailed,
                    .invalidAddress,
                    .invalidEmail,
                    .invalidSigner,
                    .notStarted:
                throw .transactionSigningFailed(error)
            }
        }

        _ = try await smartWalletService.signTransaction(
            .init(
                transactionId: transactionId,
                apiRequest: request,
                chainType: chain.chainType
            )
        )
    }

    private func createTransaction(
        _ transactionRequest: any TransactionRequest
    ) async throws(TransactionError) -> Transaction? {
        try await smartWalletService.createTransaction(
            .init(request: transactionRequest, chainType: chain.chainType)
        ).toDomain(withService: smartWalletService)
    }

    private func signTransactionIfRequired(
        _ transaction: Transaction?
    ) async throws(TransactionError) -> Transaction? {
        if let transaction, let approvals = transaction.approvals, !approvals.pending.isEmpty {
            Logger.smartWallet.debug("wallet.signTransaction.pendingApprovals", attributes: [
                "count": "\(approvals.pending.count)",
                "signers": approvals.pending.map(\.signer).joined(separator: ", ")
            ])
            for pendingApproval in approvals.pending {
                try await approveTransaction(
                    transactionId: transaction.id,
                    signerLocator: pendingApproval.signer,
                    message: pendingApproval.message
                )
            }
            return transaction
        }
        return transaction
    }

    private func pollTransactionWhilePending(
        transaction: Transaction?
    ) async throws(TransactionError) -> Transaction? {
        guard let transaction else { return nil }

        var updatedTransaction = transaction
        while updatedTransaction.status == .pending || updatedTransaction.status == .awaitingApproval {
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second in nanoseconds
            } catch {
                // If sleep fails, continue with the loop
            }

            guard let fetchedTransaction = try await smartWalletService.fetchTransaction(
                .init(transactionId: updatedTransaction.id, chainType: chain.chainType),
            ).toDomain(withService: smartWalletService) else {
                throw TransactionError.transactionGeneric("Unknown error")
            }

            updatedTransaction = fetchedTransaction
        }

        return updatedTransaction
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
