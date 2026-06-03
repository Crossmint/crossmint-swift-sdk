import CrossmintCommonTypes
import DeviceSigner
import Foundation
import Logger

extension WalletCore {
    func sendTransaction(_ params: TransactionParams) async throws(TransactionError) -> TransactionResult {
        try await preAuth()
        onTransactionStart?()
        let request = try makeTransactionRequest(params)
        let created = try await createRawTransaction(request)
        let signed = try await signTransactionIfRequired(created)
        do {
            return try await pollToCompletion(signed).toTransactionResult()
        } catch TransactionError.serviceError(let serviceError) {
            if case .invalidApiKey = serviceError {
                Logger.smartWallet.warn("Transaction polling skipped: insufficient API key permissions. ID: \(created.id)")
                return created.toTransactionResult()
            }
            throw .serviceError(serviceError)
        }
    }

    func createTransaction(_ params: TransactionParams) async throws(TransactionError) -> PendingTransaction {
        try await preAuth()
        onTransactionStart?()
        let request = try makeTransactionRequest(params)
        return try await createRawTransaction(request).toPendingTransaction()
    }

    func approve(transactionId: String) async throws(TransactionError) -> TransactionResult {
        Logger.smartWallet.info(LogEvents.walletApproveStart, attributes: ["transactionId": transactionId])
        try await preAuth()
        let transaction = try await fetchTransaction(withId: transactionId)
        let signed = try await signTransactionIfRequired(transaction)
        let completed = try await pollToCompletion(signed)
        Logger.smartWallet.info(LogEvents.walletApproveSuccessTransaction, attributes: ["transactionId": completed.id])
        return completed.toTransactionResult()
    }

    func send(to recipient: String, token: String, amount: Decimal) async throws(TransactionError) -> TransactionResult {
        Logger.smartWallet.debug(LogEvents.walletSendStart, attributes: ["recipient": recipient, "token": token, "amount": "\(amount)"])
        try await preAuth()
        onTransactionStart?()
        if let storage = deviceSignerKeyStorage {
            await deviceSignerService.ensureRegistered(storage: storage, signer: await resolveActiveSigner())
        }
        let signerLocator = await resolveActiveSignerLocator()
        let transferRequest = TransferTokenRequest(
            chainType: chain.chainType,
            tokenLocator: token,
            recipient: recipient,
            amount: "\(amount)",
            signer: signerLocator,
            idempotencyKey: nil
        )
        let created = try await smartWalletService.transferToken(transferRequest)
            .toDomain(withService: smartWalletService)
        guard let created else { throw .transactionGeneric("Unknown error") }
        let signed = try await signTransactionIfRequired(created)
        let completed = try await pollToCompletion(signed)
        Logger.smartWallet.debug(LogEvents.walletSendSuccess, attributes: ["transactionId": completed.id])
        return completed.toTransactionResult()
    }

    // MARK: - Private

    private func preAuth() async throws(TransactionError) {
        do { try await preAuthIfNeeded() } catch { throw .transactionGeneric(error.errorMessage) }
    }

    private func makeTransactionRequest(_ params: TransactionParams) throws(TransactionError) -> any TransactionRequest {
        switch params {
        case .evm(let evmParams):
            guard let evmChain = EVMChain(chain.name) else {
                throw .transactionGeneric("EVM transaction params require an EVM chain wallet")
            }
            guard let evmAddress = try? EVMAddress(address: evmParams.to) else {
                throw .transactionGeneric("Invalid EVM address: \(evmParams.to)")
            }
            return CreateEVMTransactionRequest(
                contractAddress: evmAddress,
                value: evmParams.value ?? "0",
                data: evmParams.data ?? "0x",
                chain: evmChain,
                signer: selectedSignerLocator ?? config.recovery.locator
            )
        case .solana(let solanaParams):
            return CreateSolanaTransactionRequest(transaction: solanaParams.serializedTransaction)
        case .stellar(let stellarParams):
            return CreateStellarTransactionRequest(transaction: stellarParams.serializedTransaction)
        }
    }

    private func createRawTransaction(_ request: any TransactionRequest) async throws(TransactionError) -> Transaction {
        guard let transaction = try await smartWalletService.createTransaction(
            .init(request: request, chainType: chain.chainType)
        ).toDomain(withService: smartWalletService) else {
            throw .transactionGeneric("Unknown error")
        }
        return transaction
    }

    private func fetchTransaction(withId id: String) async throws(TransactionError) -> Transaction {
        guard let transaction = try await smartWalletService.fetchTransaction(
            .init(transactionId: id, chainType: chain.chainType)
        ).toDomain(withService: smartWalletService) else {
            throw .transactionGeneric("Unknown error")
        }
        return transaction
    }

    private func signTransactionIfRequired(_ transaction: Transaction) async throws(TransactionError) -> Transaction {
        guard let approvals = transaction.approvals, !approvals.pending.isEmpty else { return transaction }
        Logger.smartWallet.debug("wallet.signTransaction.pendingApprovals", attributes: [
            "count": "\(approvals.pending.count)",
            "signers": approvals.pending.map(\.signer).joined(separator: ", ")
        ])
        for pending in approvals.pending {
            try await approveTransaction(transactionId: transaction.id, signerLocator: pending.signer, message: pending.message)
        }
        return transaction
    }

    private func approveTransaction(transactionId: String, signerLocator: String, message: String) async throws(TransactionError) {
        if signerLocator.hasPrefix("device:") {
            try await approveTransactionWithDeviceSigner(transactionId: transactionId, signerLocator: signerLocator, message: message)
        } else {
            try await approveTransactionWithActiveSigner(transactionId: transactionId, message: message)
        }
    }

    private func approveTransactionWithDeviceSigner(
        transactionId: String,
        signerLocator: String,
        message: String
    ) async throws(TransactionError) {
        guard let storage = deviceSignerKeyStorage else {
            throw .transactionSigningFailed(DeviceSignerError.keyNotFound)
        }
        let request: SignRequestApi
        do {
            request = try await deviceSignerService.buildSignRequest(signerLocator: signerLocator, message: message, storage: storage)
        } catch {
            throw .transactionSigningFailed(error)
        }
        _ = try await smartWalletService.signTransaction(.init(transactionId: transactionId, apiRequest: request, chainType: chain.chainType))
    }

    private func approveTransactionWithActiveSigner(transactionId: String, message: String) async throws(TransactionError) {
        let activeSigner = await resolveActiveSigner()
        do {
            try await activeSigner.initialize(smartWalletService)
            let request = try await buildSignRequest(signer: activeSigner, message: message)
            _ = try await smartWalletService.signTransaction(.init(transactionId: transactionId, apiRequest: request, chainType: chain.chainType))
        } catch {
            throw mapToTransactionError(error)
        }
    }

    private func pollToCompletion(_ transaction: Transaction) async throws(TransactionError) -> Transaction {
        var current = transaction
        while current.status == .pending || current.status == .awaitingApproval {
            do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { throw .userCancelled }
            current = try await fetchTransaction(withId: current.id)
        }
        return current
    }

    private func resolveActiveSignerLocator() async -> String? {
        if let active = selectedSignerLocator { return active }
        if let storage = deviceSignerKeyStorage { return await deviceSignerService.locator(for: storage) }
        return nil
    }

    private func mapToTransactionError(_ error: any Error) -> TransactionError {
        guard let signerError = error as? SignerError else { return .transactionGeneric(error.localizedDescription) }
        switch signerError {
        case .invalidMessage: return .transactionSigningFailedNoMessage
        case .invalidPrivateKey: return .transactionSigningFailedInvalidKey
        case .cancelled: return .userCancelled
        case .passkey(let e): return e == .cancelled ? .userCancelled : .transactionSigningFailed(signerError)
        default: return .transactionSigningFailed(signerError)
        }
    }
}
