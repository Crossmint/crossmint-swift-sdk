import CrossmintCommonTypes
import DeviceSigner
import Logger

extension WalletCore {
    func signMessage(_ message: String) async throws(SignatureError) -> SignatureResult {
        Logger.smartWallet.info(LogEvents.evmSignMessageStart)
        let request = CreateSignatureRequest(
            signMessageRequest: SignMessageRequest(params: .init(message: message, chain: chain, signer: config.recovery)),
            chainType: chain.chainType
        )
        return try await orchestrateSignature(request: request, signer: config.recovery)
    }

    func signTypedData(_ typedData: EIP712.TypedData, signer: (any AdminSignerData)? = nil) async throws(SignatureError) -> SignatureResult {
        Logger.smartWallet.info(LogEvents.evmSignTypedDataStart)
        let adminSigner = signer ?? config.recovery
        let signatureRequest = typedData.toSignTypedDataRequest(chain: chain, signer: adminSigner, isSmartWalletSignature: true)
        let request = CreateSignatureRequest(signTypedDataRequest: signatureRequest, chainType: chain.chainType)
        return try await orchestrateSignature(request: request, signer: adminSigner)
    }

    // MARK: - Private

    private func orchestrateSignature(request: CreateSignatureRequest, signer: any AdminSignerData) async throws(SignatureError) -> SignatureResult {
        let response = try await smartWalletService.createSignature(request)
        for pending in response.approvals.pending {
            try await approveSignature(signatureId: response.id, signerLocator: pending.signer.locator, message: pending.message)
        }
        let completed = try await pollSignatureToCompletion(signatureId: response.id, chainType: chain.chainType)
        guard let signature = extractSignature(from: completed, signer: signer) else { throw .approvalFailed }
        return SignatureResult(signatureId: response.id, signature: signature)
    }

    private func approveSignature(signatureId: String, signerLocator: String, message: String) async throws(SignatureError) {
        if signerLocator.hasPrefix("device:") {
            try await approveSignatureWithDeviceSigner(signatureId: signatureId, signerLocator: signerLocator, message: message)
        } else {
            try await approveSignatureWithActiveSigner(signatureId: signatureId, message: message)
        }
    }

    private func approveSignatureWithDeviceSigner(signatureId: String, signerLocator: String, message: String) async throws(SignatureError) {
        guard let storage = deviceSignerKeyStorage else { throw .approvalFailed }
        let request: SignRequestApi
        do {
            request = try await deviceSignerService.buildSignRequest(signerLocator: signerLocator, message: message, storage: storage)
        } catch { throw .approvalFailed }
        try await smartWalletService.approveSignature(.init(transactionId: signatureId, apiRequest: request, chainType: chain.chainType))
    }

    private func approveSignatureWithActiveSigner(signatureId: String, message: String) async throws(SignatureError) {
        let activeSigner = await resolveActiveSigner()
        let request: SignRequestApi
        do {
            request = try await buildSignRequest(signer: activeSigner, message: message)
        } catch {
            guard let signerError = error as? SignerError else { throw .approvalFailed }
            switch signerError {
            case .passkey(let e): throw e == .cancelled ? .userCancelled : .approvalFailed
            case .cancelled: throw .userCancelled
            default: throw .approvalFailed
            }
        }
        try await smartWalletService.approveSignature(.init(transactionId: signatureId, apiRequest: request, chainType: chain.chainType))
    }

    private func pollSignatureToCompletion(signatureId: String, chainType: ChainType) async throws(SignatureError) -> any SignatureApiModel {
        var signature = try await smartWalletService.fetchSignature(signatureId, chainType: chainType)
        while signature.status == "awaiting-approval" || signature.status == "pending" {
            do { try await Task.sleep(nanoseconds: 500_000_000) } catch { throw .userCancelled }
            signature = try await smartWalletService.fetchSignature(signatureId, chainType: chainType)
        }
        return signature
    }

    private func extractSignature(from response: any SignatureApiModel, signer: any AdminSignerData) -> String? {
        response.approvals.submitted.first { $0.signer.locator == signer.locator }?.signature
    }
}
