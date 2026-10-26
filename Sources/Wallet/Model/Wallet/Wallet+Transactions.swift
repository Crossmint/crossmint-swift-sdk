import CrossmintCommonTypes
import Foundation
import Logger

extension Wallet {

    // MARK: - Public API

    /// Approves and submits a pending transaction on behalf of the current signer.
    ///
    /// Use this when a transaction was created externally (e.g. via the Crossmint API) and
    /// shows ``TransactionStatus/awaitingApproval``. The SDK signs the approval message and
    /// polls until the transaction reaches a terminal state.
    ///
    /// If a quorum must approve the transaction, the SDK approves as each member that this device has a signer for.
    /// When only other members must still approve, the SDK returns the transaction with the status
    /// ``TransactionStatus/awaitingApproval``. ``Transaction/Approvals/quorums`` shows the progress.
    ///
    /// - Parameter id: The transaction ID returned by the Crossmint API.
    public func approve(transactionId id: String) async throws(TransactionError) -> Transaction {
        Logger.smartWallet.info(LogEvents.walletApproveStart, attributes: [
            "transactionId": id
        ])

        do {
            try await preAuthIfNeeded()
        } catch {
            throw .transactionGeneric(error.message)
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

    /// Fetches a page of the transaction history for this wallet, ordered most recent first.
    ///
    /// - Parameters:
    ///   - page: One-based page index.
    ///   - transactionsPerPage: Number of transactions per page.
    /// - Returns: The wallet's ``Transaction`` list for the requested page.
    ///
    /// - Throws: ``TransactionError`` if the request fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let transactions = try await wallet.listTransactions(page: 1, transactionsPerPage: 20)
    ///
    /// for transaction in transactions {
    ///     print("\(transaction.id): \(transaction.status)")
    /// }
    /// ```
    public func listTransactions(page: Int, transactionsPerPage: Int) async throws(TransactionError) -> [Transaction] {
        Logger.smartWallet.debug(LogEvents.walletListTransactionsStart, attributes: [
            "page": "\(page)",
            "perPage": "\(transactionsPerPage)"
        ])

        do {
            let transactions = try await smartWalletService.listTransactions(
                .init(chainType: chain.chainType, page: page, perPage: transactionsPerPage)
            )
            Logger.smartWallet.debug(LogEvents.walletListTransactionsSuccess, attributes: [
                "count": "\(transactions.count)"
            ])
            return transactions
        } catch {
            Logger.smartWallet.error(LogEvents.walletListTransactionsError, attributes: [
                "error": "\(error)"
            ])
            throw error
        }
    }

    /// Fetches a transaction by its ID.
    ///
    /// Use this to check the current status of a transaction, including its
    /// ``TransactionStatus``, on-chain data, and any pending or submitted approvals.
    ///
    /// - Parameter id: The transaction ID returned by the Crossmint API.
    /// - Returns: The ``Transaction`` matching the given ID.
    /// - Throws: ``TransactionError`` if the transaction cannot be retrieved or decoded.
    ///
    /// ## Example
    /// ```swift
    /// let transaction = try await wallet.getTransaction(id: "42bbb192-...")
    /// if transaction.status == .success {
    ///     print("Confirmed:", transaction.onChain.txId ?? "")
    /// }
    /// ```
    public func getTransaction(id: String) async throws(TransactionError) -> Transaction {
        Logger.smartWallet.debug(LogEvents.walletGetTransactionStart, attributes: [
            "transactionId": id
        ])

        do {
            let transaction = try await self.transaction(withId: id)
            Logger.smartWallet.debug(LogEvents.walletGetTransactionSuccess, attributes: [
                "transactionId": transaction.id,
                "status": transaction.status.rawValue
            ])
            return transaction
        } catch {
            Logger.smartWallet.error(LogEvents.walletGetTransactionError, attributes: [
                "transactionId": id,
                "error": "\(error)"
            ])
            throw error
        }
    }

    /// Removes an assigned signer from this wallet.
    ///
    /// This method submits a remove-signer transaction on-chain. If the transaction needs approval,
    /// the current signer signs it. The method then polls until the transaction completes.
    ///
    /// - Parameter locator: The signer locator string that identifies the signer to remove,
    ///   for example `"device:ABC123..."` or `"external-wallet:0x456..."`.
    /// - Returns: The completed ``Transaction`` once the signer has been removed on-chain.
    @available(*, deprecated, message: "Use the SignerLocator overload instead of raw strings.")
    public func removeSigner(locator: String) async throws(TransactionError) -> Transaction {
        try await removeSignerByLocatorString(locator)
    }

    /// Removes an assigned signer from this wallet.
    ///
    /// This method submits a remove-signer transaction on-chain. If the transaction needs approval,
    /// the current signer signs it. The method then polls until the transaction completes.
    ///
    /// Use ``removeRecoveryMethod(locator:)`` to remove a recovery method.
    ///
    /// - Parameter locator: The locator that identifies the signer to remove.
    /// - Returns: The completed ``Transaction`` once the signer has been removed on-chain.
    public func removeSigner(locator: SignerLocator) async throws(TransactionError) -> Transaction {
        try await removeSignerByLocatorString(locator.value)
    }

    private func removeSignerByLocatorString(_ locator: String) async throws(TransactionError) -> Transaction {
        Logger.smartWallet.info(LogEvents.walletRemoveSignerStart, attributes: [
            "locator": locator
        ])

        do {
            let approver: RecoveryApprover
            do {
                approver = try await authorizingRecovery()
            } catch {
                throw TransactionError.transactionGeneric(error.message)
            }
            onTransactionStart?()
            let transactionModel = try await smartWalletService.removeSigner(
                locator,
                chainType: chain.chainType,
                chainName: chain.name,
                approver: approver.locator
            )
            let transaction = transactionModel.toDomain()
            guard let result = try await signAndPollWhilePending(transaction) else {
                throw TransactionError.transactionGeneric("Unknown error")
            }
            if result.status == .success {
                await forgetLocalDeviceKey(removedLocator: locator)
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

    private func forgetLocalDeviceKey(removedLocator: String) async {
        guard let storage = deviceSignerKeyStorage,
              case .device(let publicKey)? = try? SignerLocator(from: removedLocator),
              await storage.getKey(address: address) == publicKey else { return }
        do {
            try await storage.deleteKey(address: address)
        } catch {
            Logger.smartWallet.warning(LogEvents.walletRemoveSignerLocalKeyNotDeleted, attributes: [
                "locator": removedLocator,
                "error": "\(error)"
            ])
            return
        }
        if selectedSigner is DeviceSigner {
            selectedSigner = nil
        }
        _deviceSignerApproved = false
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

    /// Transfers tokens to another wallet and polls until the transaction is confirmed on-chain.
    ///
    /// - Parameters:
    ///   - walletLocator: Recipient address (e.g. `"0xABC..."` or a Solana public key).
    ///   - tokenLocator: `"{chain}:{token}"`, e.g. `"base-sepolia:eth"` or `"solana:usdc"`.
    ///   - amount: Amount as a human-readable decimal (e.g. `0.01` for 0.01 ETH).
    ///   - idempotencyKey: Pass a stable key to prevent duplicate transactions on retry; omit to generate one automatically.
    ///
    ///   - signer: The signer that sends the transfer. Use it to name the quorum to act for
    ///     when the active signer is a member of more than one quorum.
    ///   - prepareOnly: Pass `true` to create the transfer without approving it, also for the quorum members
    ///     that this device has a signer for. Then approve it with ``approve(transactionId:)``.
    ///
    /// If a quorum must approve the transfer, the SDK approves as each member that this device has a signer for.
    /// When other members must still approve, the SDK returns the summary with the status
    /// ``TransactionStatus/awaitingApproval``. The other members approve it with ``approve(transactionId:)``.
    ///
    /// - Returns: A ``TransactionSummary`` with the on-chain hash and explorer link once confirmed.
    ///   While the status is ``TransactionStatus/awaitingApproval``, the summary has only the transaction ID.
    ///
    /// ## Example
    /// ```swift
    /// let summary = try await wallet.send(
    ///     "0xRecipient...",
    ///     "base-sepolia:usdc",
    ///     5.0
    /// )
    /// print("Sent. Explorer:", summary.explorerLink?.absoluteString ?? "")
    /// ```
    public func send(
        _ walletLocator: String,
        _ tokenLocator: String,
        _ amount: Double,
        idempotencyKey: String? = nil,
        signer: SignerLocator? = nil,
        prepareOnly: Bool = false
    ) async throws(TransactionError) -> TransactionSummary {
        Logger.smartWallet.debug(LogEvents.walletSendStart, attributes: [
            "recipient": walletLocator,
            "tokenLocator": tokenLocator,
            "amount": "\(amount)"
        ])

        let polledTransaction = try await transferTokenAndPollWhilePending(
            tokenLocator: tokenLocator,
            recipient: walletLocator,
            amount: String(amount),
            idempotencyKey: idempotencyKey,
            signer: signer,
            prepareOnly: prepareOnly
        )
        if let polledTransaction, prepareOnly || polledTransaction.awaitsQuorumMembers {
            return polledTransaction.pendingSummary
        }
        guard let transaction = polledTransaction?.toCompleted() else {
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

    /// Transfers an NFT or fungible token to a recipient.
    ///
    /// - Parameters:
    ///   - tokenId: NFT token ID to transfer; omit for fungible token transfers.
    ///   - recipient: Recipient address or wallet locator.
    ///   - amount: Amount as a string (e.g. `"1"` for one NFT, or a fungible amount).
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

    // MARK: - Internal

    internal func sendTransaction(
        _ transactionRequest: any TransactionRequest,
        prepareOnly: Bool = false
    ) async throws(TransactionError) -> Transaction? {
        do { try await preAuthIfNeeded() } catch {
            throw .transactionGeneric(error.message)
        }
        onTransactionStart?()
        let createdTransaction = try await createTransaction(transactionRequest)
        if prepareOnly { return createdTransaction }
        let signedTransaction = try await signTransactionIfRequired(createdTransaction)

        let polledTransaction: Transaction?
        do {
            polledTransaction = try await pollTransactionWhilePending(transaction: signedTransaction)
        } catch {
            switch error {
            case .serviceError(let crossmintServiceError):
                if case .invalidApiKey = crossmintServiceError {
                    Logger.smartWallet.warning(
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
        return polledTransaction
    }

    internal func transferTokenAndPollWhilePending(
        tokenLocator: String,
        recipient: String,
        amount: String,
        idempotencyKey: String? = nil,
        signer: SignerLocator? = nil,
        prepareOnly: Bool = false
    ) async throws(TransactionError) -> Transaction? {
        do { try await preAuthIfNeeded() } catch {
            throw .transactionGeneric(error.message)
        }
        onTransactionStart?()
        if let storage = deviceSignerKeyStorage, !_deviceSignerUnsupported {
            do {
                try await deviceSignerService.ensureRegistered(
                    storage: storage,
                    approver: try await authorizingRecovery()
                )
            } catch {
                if case .deviceSignerNotSupported = error {
                    _deviceSignerUnsupported = true
                }
            }
        }
        let signerLocator: String?
        if let signer {
            signerLocator = signer.value
        } else if selectedSigner == nil, let deviceLocator = await localDeviceSigner() {
            signerLocator = deviceLocator.value
        } else {
            signerLocator = try await transactionSignerLocator()
        }
        let transferRequest = TransferTokenRequest(
            chainType: chain.chainType,
            tokenLocator: tokenLocator,
            recipient: recipient,
            amount: amount,
            signer: signerLocator,
            idempotencyKey: idempotencyKey
        )
        let createdTransaction = try await smartWalletService.transferToken(transferRequest)
            .toDomain()

        if prepareOnly { return createdTransaction }
        let signedTransaction = try await signTransactionIfRequired(createdTransaction)
        return try await pollTransactionWhilePending(transaction: signedTransaction)
    }

    internal func transactionSignerLocator(explicit: SignerLocator? = nil) async throws(TransactionError) -> String? {
        if let explicit { return explicit.value }
        if let selected = try await selectedSignerLocatorForTransactions() {
            return (try await quorumRole(of: selected) ?? selected).value
        }
        guard config.recoveryMethods.count > 1 else { return nil }
        return await signer?.adminSigner.locator ?? config.recovery.locator
    }

    private var hasSigner: Bool {
        get async {
            if selectedSigner != nil || selectedRecoveryMethod != nil || signer != nil { return true }
            return await localDeviceSigner() != nil
        }
    }

    internal func selectedSignerLocatorForTransactions() async throws(TransactionError) -> SignerLocator? {
        guard await hasSigner else { throw .transactionCreationFailedNoSigner }
        do {
            return try await selectedSignerLocator()
        } catch {
            if case .device(let deviceError) = error { throw .transactionSigningFailed(deviceError) }
            throw .transactionSigningFailed(error)
        }
    }

    internal func signAndPollWhilePending(_ transaction: Transaction?) async throws(TransactionError) -> Transaction? {
        let signedTransaction = try await signTransactionIfRequired(transaction)
        return try await pollTransactionWhilePending(transaction: signedTransaction)
    }

    private func quorumRole(of locator: SignerLocator) async throws(TransactionError) -> SignerLocator? {
        let quorums = config.recoveryMethods
            .compactMap { $0 as? QuorumSignerData }
            .filter { quorum in quorum.members.contains { (try? SignerLocator(from: $0.locator)) == locator } }
            .map { SignerLocator.quorum(id: $0.id) }
        guard !quorums.isEmpty, !config.containsRecoveryMethod(locator) else { return nil }
        let registered: Bool
        do {
            registered = try await fetchSignerRegistration(locator)
        } catch {
            throw .transactionGeneric(error.message)
        }
        if registered { return nil }
        guard quorums.count == 1 else { throw .quorumSelectionAmbiguous(quorums: quorums) }
        return quorums[0]
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

    // MARK: - Private helpers

    private func transaction(withId id: String) async throws(TransactionError) -> Transaction {
        try await smartWalletService.fetchTransaction(
            .init(transactionId: id, chainType: chain.chainType)
        ).toDomain()
    }

    private func approveTransaction(
        transactionId: String,
        signerLocator: String,
        message: String
    ) async throws(TransactionError) {
        let request = try await signRequest(for: signerLocator, message: message)
        _ = try await smartWalletService.signTransaction(
            .init(transactionId: transactionId, apiRequest: request, chainType: chain.chainType)
        )
    }

    private func signRequest(
        for signerLocator: String,
        message: String
    ) async throws(TransactionError) -> SignRequestApi {
        do {
            return try await makeSignRequest(for: signerLocator, message: message)
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
            case .device(let deviceError):
                throw .transactionSigningFailed(deviceError)
            case .signingFailed,
                    .invalidAddress,
                    .invalidEmail,
                    .invalidSigner,
                    .notStarted:
                throw .transactionSigningFailed(error)
            }
        }
    }

    private func createTransaction(
        _ transactionRequest: any TransactionRequest
    ) async throws(TransactionError) -> Transaction? {
        try await smartWalletService.createTransaction(
            .init(request: transactionRequest, chainType: chain.chainType)
        ).toDomain()
    }

    private func signTransactionIfRequired(
        _ transaction: Transaction?
    ) async throws(TransactionError) -> Transaction? {
        if let transaction, let approvals = transaction.approvals, !approvals.pending.isEmpty {
            Logger.smartWallet.debug("wallet.signTransaction.pendingApprovals", attributes: [
                "count": "\(approvals.pending.count)",
                "signers": approvals.pending.map(\.signer).joined(separator: ", ")
            ])
            for pendingApproval in approvals.pending
            where !SignerLocator(orUnknown: pendingApproval.signer).isApiKey {
                try await approveTransaction(
                    transactionId: transaction.id,
                    signerLocator: pendingApproval.signer,
                    message: pendingApproval.message
                )
            }
        }
        if let transaction, let approvals = transaction.approvals {
            try await approveAsQuorumMembers(of: approvals.quorums, transactionId: transaction.id)
        }
        return transaction
    }

    private func approveAsQuorumMembers(
        of quorums: [Transaction.Approvals.QuorumProgress],
        transactionId: String
    ) async throws(TransactionError) {
        var memberApprovals: [SignRequestApi.Approval] = []
        var signedMembers = 0
        for quorum in quorums where quorum.remaining > 0 {
            for member in quorum.pending {
                guard (try? await approvalSigner(for: member.signer)) != nil else {
                    Logger.smartWallet.info(LogEvents.walletApproveQuorumMemberSkipped, attributes: [
                        "quorum": quorum.signer.value,
                        "member": member.signer
                    ])
                    continue
                }
                memberApprovals += try await signRequest(for: member.signer, message: member.message).approvals
                signedMembers += 1
            }
        }
        guard signedMembers > 0 else { return }
        _ = try await smartWalletService.signTransaction(
            .init(
                transactionId: transactionId,
                apiRequest: SignRequestApi(approvals: memberApprovals),
                chainType: chain.chainType
            )
        )
    }

    private func pollTransactionWhilePending(
        transaction: Transaction?
    ) async throws(TransactionError) -> Transaction? {
        guard let transaction else { return nil }

        var updatedTransaction = transaction
        while updatedTransaction.status == .pending || updatedTransaction.status == .awaitingApproval {
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
                throw .userCancelled
            }

            updatedTransaction = try await smartWalletService.fetchTransaction(
                .init(transactionId: updatedTransaction.id, chainType: chain.chainType)
            ).toDomain()
            if updatedTransaction.awaitsQuorumMembers { break }
        }

        return updatedTransaction
    }
}
