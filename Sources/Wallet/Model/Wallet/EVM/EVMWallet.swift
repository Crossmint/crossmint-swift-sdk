import BigInt
import CrossmintCommonTypes
import Foundation

open class EVMWallet: Wallet, WalletOnChain, @unchecked Sendable {
    public typealias SpecificChain = EVMChain

    public static func from(wallet: Wallet) throws(WalletError) -> EVMWallet {
        guard let evmWallet = wallet as? EVMWallet else {
            throw .walletInvalidType("Cannot create an EVMWallet with the provided wallet")
        }
        return evmWallet
    }

    private let evmChain: EVMChain

    internal init(
        smartWalletService: SmartWalletService,
        signer: any Signer,
        baseModel: WalletApiModel,
        evmChain: EVMChain,
        onTransactionStart: (() -> Void)? = nil
    ) throws(WalletError) {
        self.evmChain = evmChain
        do {
            try super.init(
                smartWalletService: smartWalletService,
                signer: signer,
                baseModel: baseModel,
                chain: evmChain.chain,
                address: .evm(try EVMAddress(address: baseModel.address)),
                onTransactionStart: onTransactionStart
            )
        } catch {
            throw .walletInvalidType("The address \(baseModel.address) is not compatible with EVM")
        }
    }

    @available(*, deprecated, renamed: "sendTransaction(to:value:data:)", message: "Use the new sendTransaction method. This one will be removed.")
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
                signer: self.config.adminSigner.locator
            )
        ) else {
            throw .transactionGeneric("Unknown error")
        }

        return transaction
    }

    public func sendTransaction(
        to address: String,
        value: String?,
        data: String?,
        chain: EVMChain? = nil
    ) async throws(TransactionError) -> TransactionSummary {
        guard let evmAddress = try? EVMAddress(address: address) else {
            throw .transactionGeneric("Invalid address")
        }

        guard let completedTransaction = try await super.sendTransaction(
            CreateEVMTransactionRequest(
                contractAddress: evmAddress,
                value: value ?? "0",
                data: data ?? "0x",
                chain: chain ?? self.evmChain,
                signer: self.config.adminSigner.locator
            )
        )?.toCompleted() else {
            throw .transactionGeneric("Unknown error")
        }

        return completedTransaction.summary
    }

    public func signMessage(
        _ message: String,
        signer: (any AdminSignerData)? = nil,
        isSmartWalletSignature: Bool = true
    ) async throws(SignatureError) -> String {
        let signer = signer ?? self.config.adminSigner

        let signatureRequest = SignMessageRequest(
            params: SignMessageRequest.Params(
                message: message,
                chain: super.chain,
                signer: signer,
                isSmartWalletSignature: isSmartWalletSignature
            )
        )

        let response = try await createAndApproveSignature(
            request: .init(
                signMessageRequest: signatureRequest,
                chainType: chain.chainType
            )
        )

        let completedSignature = try await pollSignatureWhilePending(
            signatureId: response.id,
            chainType: chain.chainType
        )

        guard let signature = extractSignature(from: completedSignature, for: signer) else {
            throw .approvalFailed
        }

        return signature
    }

    public func signTypedData(
        _ typedData: EIP712.TypedData,
        signer: (any AdminSignerData)? = nil,
        isSmartWalletSignature: Bool = true
    ) async throws(SignatureError) -> String {
        let signer = signer ?? self.config.adminSigner

        let signatureRequest = typedData.toSignTypedDataRequest(
            chain: super.chain,
            signer: signer,
            isSmartWalletSignature: isSmartWalletSignature
        )

        let response = try await createAndApproveSignature(
            request: .init(
                signTypedDataRequest: signatureRequest,
                chainType: chain.chainType
            )
        )

        // Poll for completed signature
        let completedSignature = try await pollSignatureWhilePending(
            signatureId: response.id,
            chainType: chain.chainType
        )

        // Extract the signature from the completed response
        guard let signature = extractSignature(from: completedSignature, for: signer) else {
            throw .approvalFailed
        }

        return signature
    }

    private func createAndApproveSignature(request: CreateSignatureRequest) async throws(SignatureError) -> any SignatureApiModel {
        let response = try await super.smartWalletService.createSignature(request)

        for pendingApproval in response.approvals.pending {
            try await approveSignature(signatureID: response.id, message: pendingApproval.message)
        }

        return response
    }

    private func pollSignatureWhilePending(
        signatureId: String,
        chainType: ChainType
    ) async throws(SignatureError) -> any SignatureApiModel {
        var signature = try await super.smartWalletService.fetchSignature(signatureId, chainType: chainType)

        while signature.status == "awaiting-approval" || signature.status == "pending" {
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
        message: String
    ) async throws(SignatureError) {
        let updatedSigner: any Signer = await updateSignerIfRequired()

        let request: SignRequestApi
        do {
            request = SignRequestApi(
                approvals: try await updatedSigner.approvals(
                    withSignature: try await updatedSigner.sign(message: message)
                )
            )
        } catch {
            switch error {
            case .passkey(let passkeyError):
                switch passkeyError {
                case .cancelled:
                    throw .userCancelled
                default:
                    throw .approvalFailed
                }
            case .signingFailed,
                    .invalidAddress,
                    .invalidEmail,
                    .invalidSigner,
                    .invalidMessage,
                    .invalidPrivateKey,
                    .notStarted,
                    .cancelled:
                throw .approvalFailed
            }
        }

        return try await smartWalletService.approveSignature(
            .init(
                transactionId: signatureID,
                apiRequest: request,
                chainType: chain.chainType
            )
        )
    }
}
