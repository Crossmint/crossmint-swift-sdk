import CrossmintCommonTypes
import CrossmintService
import Http
import Logger

private struct TransferBody: Encodable {
    let recipient: String
    let amount: String
    let signer: String?
}

extension DefaultSmartWalletService {
    public func transferToken(
        chainType: ChainType,
        tokenLocator: String,
        recipient: String,
        amount: String,
        signer: String? = nil,
        idempotencyKey: String? = nil
    ) async throws(TransactionError) -> any TransactionApiModel {
        Logger.smartWallet.info(LogEvents.apiSendStart, attributes: [
            "walletLocator": "me:\(chainType.rawValue)",
            "recipient": recipient,
            "token": tokenLocator,
            "amount": amount
        ])
        return try await executeTransfer(
            chainType: chainType,
            tokenLocator: tokenLocator,
            recipient: recipient,
            amount: amount,
            signer: signer,
            idempotencyKey: idempotencyKey
        )
    }

    public func listTransfers(
        _ params: ListTransfersQueryParams
    ) async throws(WalletError) -> TransferListResult {
        Logger.smartWallet.info(LogEvents.apiListTransfersStart, attributes: [
            "walletLocator": params.walletLocator.value,
            "chain": params.chain.name
        ])
        return try await fetchTransferList(params)
    }

    private func executeTransfer(
        chainType: ChainType,
        tokenLocator: String,
        recipient: String,
        amount: String,
        signer: String?,
        idempotencyKey: String?
    ) async throws(TransactionError) -> any TransactionApiModel {
        let body = TransferBody(recipient: recipient, amount: amount, signer: signer)
        let bodyData = try jsonCoder.encodeRequest(body, errorType: TransactionError.self)
        var headers = await authHeaders
        // Always send an idempotency key — callers that need idempotency supply their own.
        headers["x-idempotency-key"] = idempotencyKey ?? UUID().uuidString
        let endpoint = Endpoint.meWalletTokenTransfer(chainType: chainType, tokenLocator: tokenLocator, headers: headers, body: bodyData)
        return try await loggedTransfer(endpoint: endpoint, chainType: chainType)
    }

    private func loggedTransfer(
        endpoint: Endpoint,
        chainType: ChainType
    ) async throws(TransactionError) -> any TransactionApiModel {
        do {
            let result = try await executeTransactionRequest(endpoint: endpoint, mapping: chainType.mappingType)
            Logger.smartWallet.info(LogEvents.apiSendSuccess, attributes: ["transactionId": "\(result.id)"])
            return result
        } catch {
            Logger.smartWallet.error(LogEvents.apiSendError, attributes: ["error": "\(error)"])
            throw error
        }
    }

    private func fetchTransferList(
        _ params: ListTransfersQueryParams
    ) async throws(WalletError) -> TransferListResult {
        let queryItems = makeListTransfersQueryItems(for: params)
        let endpoint = Endpoint.meWalletTransferList(
            chainType: params.chain.chainType,
            headers: await authHeaders,
            queryItems: queryItems
        )
        do {
            let response: TransferListApiModel = try await crossmintService.executeRequest(endpoint, errorType: WalletError.self)
            let result = mapTransferListResponse(response)
            Logger.smartWallet.info(LogEvents.apiListTransfersSuccess, attributes: ["count": "\(result.transfers.count)"])
            return result
        } catch {
            Logger.smartWallet.warn(LogEvents.apiListTransfersError, attributes: ["error": "\(error)"])
            throw error
        }
    }

    private func mapTransferListResponse(_ response: TransferListApiModel) -> TransferListResult {
        let transfers = response.data.compactMap { Transfer.map($0) }
        return TransferListResult(transfers: transfers)
    }

    private func makeListTransfersQueryItems(for params: ListTransfersQueryParams) -> [URLQueryItem] {
        var queryItems: [URLQueryItem] = [
            .init(name: "chain", value: params.chain.name),
            .init(name: "status", value: "successful")
        ]
        if !params.tokens.isEmpty {
            let tokenValue = params.tokens.map(\.name).joined(separator: ",")
            queryItems.append(.init(name: "tokens", value: tokenValue))
        }
        return queryItems
    }
}
