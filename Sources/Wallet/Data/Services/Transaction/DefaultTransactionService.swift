import CrossmintCommonTypes
import CrossmintService
import Http
import Logger

struct DefaultTransactionService: TransactionService {
    let crossmintService: CrossmintService
    let jsonCoder: JSONCoder

    func createTransaction(
        _ request: CreateTransactionRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        let bodyData = try jsonCoder.encodeRequest(request.request, errorType: TransactionError.self)
        let endpoint = Endpoint.createTransaction(
            chainType: request.chainType,
            body: bodyData
        )
        return try await executeTransactionRequest(endpoint: endpoint, mapping: request.chainType.mappingType)
    }

    func signTransaction(
        _ request: SignRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        let bodyData = try jsonCoder.encodeRequest(request.apiRequest, errorType: TransactionError.self)
        let endpoint = Endpoint.approveTransaction(
            chainType: request.chainType,
            transactionId: request.transactionId,
            body: bodyData
        )
        return try await executeTransactionRequest(endpoint: endpoint, mapping: request.chainType.mappingType)
    }

    func fetchTransaction(
        _ request: FetchTransactionRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        let endpoint = Endpoint.fetchTransaction(
            chainType: request.chainType,
            transactionId: request.transactionId
        )
        return try await executeTransactionRequest(endpoint: endpoint, mapping: request.chainType.mappingType)
    }

    func listTransactions(
        chainType: ChainType
    ) async throws(TransactionError) -> [any TransactionApiModel] {
        Logger.smartWallet.info(LogEvents.apiListTransactionsStart, attributes: [
            "chain": chainType.rawValue
        ])
        let endpoint = Endpoint.listTransactions(chainType: chainType)
        do {
            let transactions = try await executeTransactionListRequest(
                endpoint: endpoint,
                mapping: chainType.mappingType
            )
            Logger.smartWallet.info(LogEvents.apiListTransactionsSuccess, attributes: [
                "count": "\(transactions.count)"
            ])
            return transactions
        } catch {
            Logger.smartWallet.warning(LogEvents.apiListTransactionsError, attributes: ["error": "\(error)"])
            throw error
        }
    }

    private func executeTransactionRequest<T: WalletTypeTransactionMapping>(
        endpoint: Endpoint,
        mapping: T.Type
    ) async throws(TransactionError) -> any TransactionApiModel {
        let data = try await crossmintService.executeRequestForRawData(
            endpoint,
            errorType: TransactionError.self
        )
        do {
            return try jsonCoder.decode(T.APIModel.self, from: data)
        } catch {
            throw TransactionError.transactionGeneric("Failed to decode transaction response")
        }
    }

    private func executeTransactionListRequest<T: WalletTypeTransactionMapping>(
        endpoint: Endpoint,
        mapping: T.Type
    ) async throws(TransactionError) -> [any TransactionApiModel] {
        let data = try await crossmintService.executeRequestForRawData(
            endpoint,
            errorType: TransactionError.self
        )
        do {
            return try jsonCoder.decode(TransactionListApiModel<T.APIModel>.self, from: data).transactions
        } catch {
            throw TransactionError.transactionGeneric("Failed to decode transaction list response")
        }
    }
}
