import CrossmintCommonTypes

extension SmartWalletService {
    /// Fetches a transaction and returns it as the domain model.
    func transaction(withId id: String, chainType: ChainType) async throws(TransactionError) -> Transaction {
        try await fetchTransaction(
            .init(transactionId: id, chainType: chainType)
        ).toDomain()
    }

    /// Signs the approval message with the given signer and submits it for the transaction.
    func signTransaction(
        transactionId: String,
        chainType: ChainType,
        signer: any Signer,
        message: String
    ) async throws {
        let request = try await makeSignRequest(signer: signer, message: message)
        _ = try await signTransaction(
            .init(transactionId: transactionId, apiRequest: request, chainType: chainType)
        )
    }

    /// Signs the approval message with the given signer and submits it for the signature.
    func approveSignature(
        signatureId: String,
        chainType: ChainType,
        signer: any Signer,
        message: String
    ) async throws {
        let request = try await makeSignRequest(signer: signer, message: message)
        try await approveSignature(
            .init(transactionId: signatureId, apiRequest: request, chainType: chainType)
        )
    }

    private func makeSignRequest(signer: any Signer, message: String) async throws(SignerError) -> SignRequestApi {
        SignRequestApi(
            approvals: try await signer.approvals(
                withSignature: try await signer.sign(message: message)
            )
        )
    }
}
