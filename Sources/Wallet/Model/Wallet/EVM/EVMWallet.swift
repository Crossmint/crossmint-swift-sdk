import BigInt
import CrossmintCommonTypes
import DeviceSigner
import Foundation
import Logger

/// A Crossmint smart wallet on an EVM-compatible chain.
///
/// Obtain an instance via ``CrossmintWallets/getWallet(chain:options:)``
/// or ``CrossmintWallets/createWallet(chain:recoveryMethods:options:)``.
open class EVMWallet: Wallet, WalletOnChain, @unchecked Sendable {
    public typealias SpecificChain = EVMChain

    /// Casts a generic ``Wallet`` to ``EVMWallet``.
    ///
    /// Useful when you have a ``Wallet`` reference and need EVM-specific methods.
    /// Throws ``WalletError`` if the wallet is not an EVM wallet.
    public static func from(wallet: Wallet) throws(WalletError) -> EVMWallet {
        guard let evmWallet = wallet as? EVMWallet else {
            throw .walletInvalidType("Cannot create an EVMWallet with the provided wallet")
        }
        return evmWallet
    }

    private let evmChain: EVMChain

    internal init(
        smartWalletService: SmartWalletService,
        signer: (any Signer)?,
        baseModel: WalletApiModel,
        evmChain: EVMChain,
        onTransactionStart: (() -> Void)? = nil,
        deviceSignerKeyStorage: (any DeviceSignerKeyStorage)? = nil,
        deviceSignerUnsupported: Bool = false
    ) throws(WalletError) {
        self.evmChain = evmChain
        do {
            try super.init(
                smartWalletService: smartWalletService,
                signer: signer,
                baseModel: baseModel,
                chain: evmChain.chain,
                address: .evm(try EVMAddress(address: baseModel.address)),
                onTransactionStart: onTransactionStart,
                deviceSignerKeyStorage: deviceSignerKeyStorage,
                deviceSignerUnsupported: deviceSignerUnsupported
            )
        } catch {
            throw .walletInvalidType("The address \(baseModel.address) is not compatible with EVM")
        }
    }

    @available(
        *, deprecated, renamed: "sendTransaction(to:value:data:)",
        message: "Use the new sendTransaction method. This one will be removed."
    )
    public func sendTransaction(
        to address: EVMAddress,
        data: String?,
        value: BigInt?,
        chain: EVMChain
    ) async throws(TransactionError) -> Transaction {
        guard let transaction = try await super.sendTransaction(
            CreateEVMTransactionRequest(
                contractAddress: address,
                value: "\(value ?? .zero)",
                data: data ?? "0x",
                chain: chain,
                signer: try await evmSignerLocator(explicit: nil)
            )
        ) else {
            throw .transactionGeneric("Unknown error")
        }

        return transaction
    }

    /// Sends a raw EVM transaction and polls until it is confirmed on-chain.
    ///
    /// - Parameters:
    ///   - address: Recipient contract or EOA address (checksummed or lowercase hex).
    ///   - value: Native token value in wei as a decimal string, e.g. `"1000000000000000"`. Pass `nil` or `"0"` for contract calls that transfer no ETH.
    ///   - data: ABI-encoded call data as a `0x`-prefixed hex string. Pass `nil` or `"0x"` for plain ETH transfers.
    ///   - chain: Target chain. Defaults to the chain the wallet was opened on.
    ///   - prepareOnly: Pass `true` to create the transaction without approving it.
    ///     Then approve it with ``Wallet/approve(transactionId:)``. The summary then has only the transaction ID.
    ///
    /// When a quorum sends the transaction, the SDK creates it without approving it, as with `prepareOnly`.
    ///
    /// ## Example
    /// ```swift
    /// // Transfer 0.001 ETH
    /// let summary = try await evmWallet.sendTransaction(
    ///     to: "0xRecipient...",
    ///     value: "1000000000000000",
    ///     data: nil
    /// )
    /// print("Confirmed:", summary.explorerLink?.absoluteString ?? "")
    /// ```
    public func sendTransaction(
        to address: String,
        value: String?,
        data: String?,
        chain: EVMChain? = nil,
        signer: SignerLocator? = nil,
        prepareOnly: Bool = false
    ) async throws(TransactionError) -> TransactionSummary {
        Logger.smartWallet.info(LogEvents.evmSendTransactionStart)

        guard let evmAddress = try? EVMAddress(address: address) else {
            throw .transactionGeneric("Invalid address")
        }

        let signerLocator = try await evmSignerLocator(explicit: signer)
        guard let transaction = try await super.sendTransaction(
            CreateEVMTransactionRequest(
                contractAddress: evmAddress,
                value: value ?? "0",
                data: data ?? "0x",
                chain: chain ?? self.evmChain,
                signer: signerLocator
            ),
            prepareOnly: prepareOnly || isQuorum(signerLocator)
        ) else {
            throw .transactionGeneric("Unknown error")
        }
        if let pending = transaction.pendingSummary { return pending }

        Logger.smartWallet.info(LogEvents.evmSendTransactionPrepared, attributes: [
            "transactionId": transaction.id
        ])

        guard let completedTransaction = transaction.toCompleted() else {
            throw .transactionGeneric("Unknown error")
        }

        Logger.smartWallet.info(LogEvents.evmSendTransactionSuccess, attributes: [
            "transactionId": completedTransaction.id,
            "hash": completedTransaction.onChain.txId
        ])

        return completedTransaction.summary
    }

    /// Signs an arbitrary message with this wallet.
    ///
    /// - Parameters:
    ///   - message: The plain-text message to sign.
    ///   - signer: Override which signer produces the signature. Defaults to the wallet's recovery signer.
    ///   - isSmartWalletSignature: When `true` (default), produces an EIP-6492 smart-wallet-compatible
    ///     signature. Set to `false` to produce a standard EOA signature instead.
    ///   - prepareOnly: Pass `true` to create the signature request without approving it.
    ///     Then approve it with ``approve(signatureId:)``.
    ///
    /// When a quorum signs, the SDK creates the request without approving it, as with `prepareOnly`.
    /// Each member then approves it with ``approve(signatureId:)``.
    ///
    /// - Returns: A ``Signature``. When the SDK does not approve the request, it has only the signature ID.
    ///
    /// ## Example
    /// ```swift
    /// let result = try await evmWallet.signMessage("Hello, Crossmint!")
    /// print(result.signature ?? "")
    /// ```
    public func signMessage(
        _ message: String,
        signer: (any AdminSignerData)? = nil,
        isSmartWalletSignature: Bool = true,
        prepareOnly: Bool = false
    ) async throws(SignatureError) -> Signature {
        Logger.smartWallet.info(LogEvents.evmSignMessageStart)

        do {
            try await preAuthIfNeeded()
        } catch {
            throw .signingFailed(underlyingError: error)
        }

        let signer = signer ?? self.config.recovery

        do {
            let signatureRequest = SignMessageRequest(
                params: SignMessageRequest.Params(
                    message: message,
                    chain: super.chain,
                    signer: signer,
                    isSmartWalletSignature: isSmartWalletSignature
                )
            )

            let response = try await super.smartWalletService.createSignature(
                .init(signMessageRequest: signatureRequest, chainType: chain.chainType)
            )

            Logger.smartWallet.info(LogEvents.evmSignMessagePrepared, attributes: [
                "signatureId": response.id
            ])

            if prepareOnly || isQuorum(signer.locator) { return Signature(id: response.id, signature: nil) }
            try await approvePendingSignatures(of: response)

            let completedSignature = try await pollSignatureWhilePending(
                signatureId: response.id,
                chainType: chain.chainType
            )

            guard let signature = extractSignature(from: completedSignature, for: signer) else {
                throw SignatureError.approvalFailed
            }

            Logger.smartWallet.info(LogEvents.evmSignMessageSuccess, attributes: [
                "signatureId": response.id
            ])

            return Signature(id: response.id, signature: signature)
        } catch {
            Logger.smartWallet.error(LogEvents.evmSignMessageError, attributes: [
                "error": "\(error)"
            ])
            throw error as? SignatureError ?? .unknown
        }
    }

    /// Signs EIP-712 typed structured data with this wallet.
    ///
    /// - Parameters:
    ///   - typedData: The structured data to sign, conforming to EIP-712.
    ///   - signer: Override which signer produces the signature. Defaults to the wallet's recovery signer.
    ///   - isSmartWalletSignature: See ``signMessage(_:signer:isSmartWalletSignature:prepareOnly:)`` for semantics.
    ///   - prepareOnly: Pass `true` to create the signature request without approving it.
    ///     Then approve it with ``approve(signatureId:)``.
    ///
    /// When a quorum signs, the SDK creates the request without approving it, as with `prepareOnly`.
    /// Each member then approves it with ``approve(signatureId:)``.
    ///
    /// - Returns: A ``Signature``. When the SDK does not approve the request, it has only the signature ID.
    public func signTypedData(
        _ typedData: EIP712.TypedData,
        signer: (any AdminSignerData)? = nil,
        isSmartWalletSignature: Bool = true,
        prepareOnly: Bool = false
    ) async throws(SignatureError) -> Signature {
        Logger.smartWallet.info(LogEvents.evmSignTypedDataStart)

        do {
            try await preAuthIfNeeded()
        } catch {
            throw .signingFailed(underlyingError: error)
        }

        let signer = signer ?? self.config.recovery

        do {
            let signatureRequest = typedData.toSignTypedDataRequest(
                chain: super.chain,
                signer: signer,
                isSmartWalletSignature: isSmartWalletSignature
            )

            let response = try await super.smartWalletService.createSignature(
                .init(signTypedDataRequest: signatureRequest, chainType: chain.chainType)
            )

            Logger.smartWallet.info(LogEvents.evmSignTypedDataPrepared, attributes: [
                "signatureId": response.id
            ])

            if prepareOnly || isQuorum(signer.locator) { return Signature(id: response.id, signature: nil) }
            try await approvePendingSignatures(of: response)

            // Poll for completed signature
            let completedSignature = try await pollSignatureWhilePending(
                signatureId: response.id,
                chainType: chain.chainType
            )

            // Extract the signature from the completed response
            guard let signature = extractSignature(from: completedSignature, for: signer) else {
                throw SignatureError.approvalFailed
            }

            Logger.smartWallet.info(LogEvents.evmSignTypedDataSuccess, attributes: [
                "signatureId": response.id
            ])

            return Signature(id: response.id, signature: signature)
        } catch {
            Logger.smartWallet.error(LogEvents.evmSignTypedDataError, attributes: [
                "error": "\(error)"
            ])
            throw error as? SignatureError ?? .unknown
        }
    }

    /// Approves a pending signature request on behalf of the signers on this device.
    ///
    /// If a quorum must approve the request, the SDK approves as each member that this device has a signer for.
    ///
    /// - Parameter id: The signature ID that ``signMessage(_:signer:isSmartWalletSignature:prepareOnly:)``
    ///   or ``signTypedData(_:signer:isSmartWalletSignature:prepareOnly:)`` returned.
    /// - Returns: A ``Signature``. While other quorum members must still approve, it has only the signature ID.
    public func approve(signatureId id: String) async throws(SignatureError) -> Signature {
        Logger.smartWallet.info(LogEvents.walletApproveStart, attributes: ["signatureId": id])
        do {
            try await preAuthIfNeeded()
        } catch {
            throw .signingFailed(underlyingError: error)
        }
        do {
            let pending = try await super.smartWalletService.fetchSignature(id, chainType: chain.chainType)
            try await approvePendingSignatures(of: pending)
            try await approveSignatureAsQuorumMembers(pending)
            let completed = try await pollSignatureWhilePending(signatureId: id, chainType: chain.chainType)
            Logger.smartWallet.info(LogEvents.walletApproveSuccessSignature, attributes: ["signatureId": id])
            return Signature(id: id, signature: completed.outputSignature)
        } catch {
            Logger.smartWallet.error(LogEvents.walletApproveError, attributes: [
                "signatureId": id,
                "error": "\(error)"
            ])
            throw error as? SignatureError ?? .unknown
        }
    }

    private func approvePendingSignatures(of response: any SignatureApiModel) async throws(SignatureError) {
        for pendingApproval in response.approvals.pending
        where !SignerLocator(orUnknown: pendingApproval.signer.locator).isApiKey {
            try await approveSignature(
                signatureID: response.id,
                signerLocator: pendingApproval.signer.locator,
                message: pendingApproval.message
            )
        }
    }

    private func approveSignatureAsQuorumMembers(_ response: any SignatureApiModel) async throws(SignatureError) {
        let memberApprovals: [SignRequestApi.Approval]
        do {
            memberApprovals = try await heldMemberApprovals(of: response.approvals.quorums.map(\.toDomain))
        } catch {
            if case .userCancelled = error { throw .userCancelled }
            throw .signingFailed(underlyingError: error)
        }
        guard !memberApprovals.isEmpty else { return }
        try await smartWalletService.approveSignature(
            .init(
                transactionId: response.id,
                apiRequest: SignRequestApi(approvals: memberApprovals),
                chainType: chain.chainType
            )
        )
    }

    private func pollSignatureWhilePending(
        signatureId: String,
        chainType: ChainType
    ) async throws(SignatureError) -> any SignatureApiModel {
        var signature = try await super.smartWalletService.fetchSignature(signatureId, chainType: chainType)

        while [.awaitingApproval, .pending].contains(SignerStatus.from(signature.status)),
              !signature.awaitsQuorumMembers {
            do {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
            } catch {
                // Continue with the loop if sleep fails
            }

            signature = try await super.smartWalletService.fetchSignature(signatureId, chainType: chainType)
        }

        return signature
    }

    private func extractSignature(
        from response: any SignatureApiModel,
        `for` adminSignerData: AdminSignerData
    ) -> String? {
        let signerApproval = response.approvals.submitted.first {
            $0.signer.locator == adminSignerData.locator
        }

        guard let signerApproval else { return nil }
        return signerApproval.signature
    }

    private func approveSignature(
        signatureID: String,
        signerLocator: String,
        message: String
    ) async throws(SignatureError) {
        let request: SignRequestApi
        do {
            request = try await makeSignRequest(for: signerLocator, message: message)
        } catch {
            throw mapSignerError(error)
        }
        try await smartWalletService.approveSignature(
            .init(transactionId: signatureID, apiRequest: request, chainType: chain.chainType)
        )
    }

    private func mapSignerError(_ error: SignerError) -> SignatureError {
        switch error {
        case .passkey(let passkeyError):
            switch passkeyError {
            case .cancelled:
                return .userCancelled
            default:
                return .signingFailed(underlyingError: error)
            }
        case .cancelled:
            return .userCancelled
        case .device(let deviceError):
            return .signingFailed(underlyingError: deviceError)
        case .signingFailed,
                .invalidAddress,
                .invalidEmail,
                .invalidSigner,
                .invalidMessage,
                .invalidPrivateKey,
                .notStarted:
            return .signingFailed(underlyingError: error)
        }
    }

    private func evmSignerLocator(explicit: SignerLocator?) async throws(TransactionError) -> String {
        try await transactionSignerLocator(explicit: explicit) ?? config.recovery.locator
    }
}
