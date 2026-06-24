import CrossmintCommonTypes
import DeviceSigner
import Foundation
import Logger

extension Wallet {

    // MARK: - Public API

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

    // MARK: - Internal

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
        let transferRequest = TransferTokenRequest(
            chainType: chain.chainType,
            tokenLocator: tokenLocator,
            recipient: recipient,
            amount: amount,
            signer: signerLocator,
            idempotencyKey: idempotencyKey
        )
        let createdTransaction = try await smartWalletService.transferToken(transferRequest)
            .toDomain(withService: smartWalletService)

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

    // MARK: - Private helpers

    private func transaction(withId id: String) async throws(TransactionError) -> Transaction {
        guard let transaction = try await smartWalletService.fetchTransaction(
                .init(transactionId: id, chainType: chain.chainType),
        ).toDomain(withService: smartWalletService) else {
            throw TransactionError.transactionGeneric("Unknown error")
        }
        return transaction
    }

    private func approveTransaction(
        transactionId: String,
        signerLocator: String,
        message: String
    ) async throws(TransactionError) {
        if signerLocator.hasPrefix("device:") {
            try await approveTransactionWithDeviceSigner(
                transactionId: transactionId,
                signerLocator: signerLocator,
                message: message
            )
        } else {
            try await approveTransactionWithActiveSigner(
                transactionId: transactionId,
                message: message
            )
        }
    }

    private func approveTransactionWithDeviceSigner(
        transactionId: String,
        signerLocator: String,
        message: String
    ) async throws(TransactionError) {
        guard let storage = deviceSignerKeyStorage else {
            throw TransactionError.transactionSigningFailed(DeviceSignerError.keyNotFound)
        }
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
    }

    private func approveTransactionWithActiveSigner(
        transactionId: String,
        message: String
    ) async throws(TransactionError) {
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
            .init(transactionId: transactionId, apiRequest: request, chainType: chain.chainType)
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
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
                throw .userCancelled
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
}
