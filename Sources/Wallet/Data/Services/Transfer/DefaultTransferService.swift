import CrossmintCommonTypes
import CrossmintService
import Http
import Logger

private struct TransferBody: Encodable {
    let recipient: String
    let amount: String
    let signer: String?
}

struct DefaultTransferService: TransferService {
    let crossmintService: CrossmintService
    let jsonCoder: JSONCoder

    func transferToken(
        _ request: TransferTokenRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        Logger.smartWallet.info(LogEvents.apiSendStart, attributes: [
            "walletLocator": "me:\(request.chainType.rawValue)",
            "recipient": request.recipient,
            "token": request.tokenLocator,
            "amount": request.amount
        ])
        return try await executeTransfer(request)
    }

    func listTransfers(
        _ params: ListTransfersQueryParams
    ) async throws(WalletError) -> TransferListResult {
        Logger.smartWallet.info(LogEvents.apiListTransfersStart, attributes: [
            "walletLocator": params.walletLocator.value,
            "chain": params.chain.name
        ])
        return try await fetchTransferList(params)
    }

    private func executeTransfer(
        _ request: TransferTokenRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        let body = TransferBody(recipient: request.recipient, amount: request.amount, signer: request.signer)
        let bodyData = try jsonCoder.encodeRequest(body, errorType: TransactionError.self)
        let headers = ["x-idempotency-key": request.idempotencyKey ?? UUID().uuidString]
        let endpoint = Endpoint.meWalletTokenTransfer(
            chainType: request.chainType,
            tokenLocator: request.tokenLocator,
            headers: headers,
            body: bodyData
        )
        return try await loggedTransfer(endpoint: endpoint, chainType: request.chainType)
    }

    private func loggedTransfer(
        endpoint: Endpoint,
        chainType: ChainType
    ) async throws(TransactionError) -> any TransactionApiModel {
        do {
            let result = try await executeTransactionRequest(endpoint: endpoint, chainType: chainType)
            Logger.smartWallet.info(LogEvents.apiSendSuccess, attributes: ["transactionId": "\(result.id)"])
            return result
        } catch {
            Logger.smartWallet.error(LogEvents.apiSendError, attributes: ["error": "\(error)"])
            throw error
        }
    }

    private func executeTransactionRequest(
        endpoint: Endpoint,
        chainType: ChainType
    ) async throws(TransactionError) -> any TransactionApiModel {
        let data = try await crossmintService.executeRequestForRawData(endpoint, errorType: TransactionError.self)
        return try decodeTransaction(from: data, mapping: chainType.mappingType)
    }

    private func decodeTransaction<T: WalletTypeTransactionMapping>(
        from data: Data,
        mapping: T.Type
    ) throws(TransactionError) -> any TransactionApiModel {
        do {
            return try jsonCoder.decode(T.APIModel.self, from: data)
        } catch {
            throw TransactionError.transactionGeneric("Failed to decode transaction response: \(error)")
        }
    }

    private func fetchTransferList(
        _ params: ListTransfersQueryParams
    ) async throws(WalletError) -> TransferListResult {
        let queryItems = makeListTransfersQueryItems(for: params)
        let endpoint = Endpoint.meWalletTransferList(
            chainType: params.chain.chainType,
            queryItems: queryItems
        )
        do {
            let response: TransferListApiModel =
                try await crossmintService.executeRequest(endpoint, errorType: WalletError.self)
            let result = mapTransferListResponse(response)
            Logger.smartWallet.info(LogEvents.apiListTransfersSuccess, attributes: [
                "count": "\(result.transfers.count)"
            ])
            return result
        } catch {
            Logger.smartWallet.warning(LogEvents.apiListTransfersError, attributes: ["error": "\(error)"])
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
